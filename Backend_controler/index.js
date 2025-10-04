// udp-smooth-controller.js
// Optimized version with time-based exponential smoothing, hysteresis, direction-rate-limiting (anti-polarisation),
// decoupled tick (fixed update rate), subpixel mouse accumulation, and fewer robotjs calls.

const dgram = require('dgram');
const robot = require('robotjs');
const os = require('os');

const UDP_PORT = 8080;

// ---------- Configurable parameters ----------
let MAX_SPEED = 80;            // px per tick baseline (will be scaled by magnitude)
let DEADZONE = 0.05;           // normalized 0..1 (enter deadzone)
let DEADZONE_EXIT = 0.035;     // hysteresis: smaller threshold to exit deadzone
let SMOOTH_TIME = 0.06;        // smoothing time constant (seconds) — smaller = snappier
let TICK_RATE = 60;            // Hz: how often we apply outputs (decouples network from robot calls)
let MOVE_THROTTLE = 1;        // not used directly now, retained for compatibility
let TURN_RATE_DEG_PER_SEC = 720; // maximum allowed change in direction in degrees per second (anti-polarisation)
let SENSITIVITY_CURVE = 1.0;  // exponent for magnitude -> speed (1.0 linear, >1 less sensitive near center)
let EPS_AXIS = 50;            // minimal axis change (in device units) to send movement (avoids noisy small moves)
let EPS_KEY_TOGGLE_MS = 30;   // minimal ms between keyboard toggles to avoid spam

const BUTTON_MAPPING = {
  right: { 0: 'enter', 1: 'tab' },
};

// dynamic config object for runtime updates
let dynamicConfig = {
  MAX_SPEED,
  DEADZONE,
  DEADZONE_EXIT,
  SMOOTH_TIME,
  TICK_RATE,
  MOVE_THROTTLE,
  TURN_RATE_DEG_PER_SEC,
  SENSITIVITY_CURVE,
};

// ---------- State ----------
let lastTime = process.hrtime.bigint();
let tickIntervalMs = Math.round(1000 / TICK_RATE);

let latestInput = {
  left: { x: 0, y: 0, ts: 0 },
  right: { x: 0, y: 0, ts: 0 },
};

let smoothed = {
  left: { x: 0, y: 0 },
  right: { x: 0, y: 0 },
};

let lastOutput = {
  leftAxes: { x: 0, y: 0 },   // normalized -1..1
  rightAxes: { x: 0, y: 0 },  // normalized -1..1
  mousePosSub: { x: 0, y: 0 },// fractional accumulator for mouse movement
};

let pressedButtons = { left: new Set(), right: new Set() };
let pressedDirectionKeys = new Set();
let lastKeyToggleTime = 0;
const screenSize = robot.getScreenSize();

// ---------- Helpers ----------
function nowMs() {
  return Number(process.hrtime.bigint() / 1000000n);
}

function applyConfig(updates) {
  if (typeof updates !== 'object') return;
  for (const [key, value] of Object.entries(updates)) {
    if (dynamicConfig.hasOwnProperty(key) && typeof value === 'number') {
      dynamicConfig[key] = value;
      console.log(`🛠️ ${key} wurde aktualisiert: ${value}`);
    }
  }
  // copy back to local variables used by fast code paths
  MAX_SPEED = dynamicConfig.MAX_SPEED;
  DEADZONE = dynamicConfig.DEADZONE;
  DEADZONE_EXIT = dynamicConfig.DEADZONE_EXIT;
  SMOOTH_TIME = dynamicConfig.SMOOTH_TIME;
  TICK_RATE = dynamicConfig.TICK_RATE;
  tickIntervalMs = Math.round(1000 / TICK_RATE);
  MOVE_THROTTLE = dynamicConfig.MOVE_THROTTLE;
  TURN_RATE_DEG_PER_SEC = dynamicConfig.TURN_RATE_DEG_PER_SEC;
  SENSITIVITY_CURVE = dynamicConfig.SENSITIVITY_CURVE;

  console.log('🔧 Aktuelle Konfiguration:', dynamicConfig);
}

// clamp helper
function clamp(v, a, b) {
  return v < a ? a : v > b ? b : v;
}

// length and normalize
function magnitude(x, y) {
  return Math.hypot(x, y);
}
function normalize(x, y) {
  const m = Math.hypot(x, y);
  if (m === 0) return [0, 0];
  return [x / m, y / m];
}

// convert normalized (-1..1) to joystick-like magnitude (0..1)
function mag01(x, y) {
  return clamp(magnitude(x, y), 0, 1);
}

// compute exponential smoothing alpha given time delta and time constant tau:
// alpha = 1 - exp(-dt/tau)
function smoothingAlpha(dtSec, tauSec) {
  if (tauSec <= 0) return 1.0;
  return 1 - Math.exp(-dtSec / tauSec);
}

// direction angle helpers (radians)
function angleOf(x, y) {
  return Math.atan2(y, x); // -pi..pi
}
function angleDiff(a, b) {
  // smallest signed difference a-b
  let d = a - b;
  while (d <= -Math.PI) d += 2 * Math.PI;
  while (d > Math.PI) d -= 2 * Math.PI;
  return d;
}

// map direction to keys (WASD) — returns a Set of keys to be pressed for current smoothed left axes
function mapDirectionToKeysFromAxes(ax, ay) {
  const keys = new Set();
  // Use cardinal thresholds: prefer diagonal combos
  if (ay < -DEADZONE) keys.add('w');
  else if (ay > DEADZONE) keys.add('s');
  if (ax < -DEADZONE) keys.add('a');
  else if (ax > DEADZONE) keys.add('d');
  return keys;
}

// keyboard update with hysteresis + rate limit
function updatePressedDirectionKeys(side, newKeys) {
  const now = nowMs();
  // remove keys no longer present
  for (const key of Array.from(pressedDirectionKeys)) {
    if (!newKeys.has(key)) {
      // rate-limit toggles a bit to avoid spam
      if (now - lastKeyToggleTime > EPS_KEY_TOGGLE_MS) {
        robot.keyToggle(key, 'up');
        console.log(`⬆️ ${side} lässt '${key}' los`);
        pressedDirectionKeys.delete(key);
        lastKeyToggleTime = now;
      }
    }
  }
  // add new keys
  for (const key of newKeys) {
    if (!pressedDirectionKeys.has(key)) {
      if (now - lastKeyToggleTime > EPS_KEY_TOGGLE_MS) {
        robot.keyToggle(key, 'down');
        console.log(`⬇️ ${side} drückt '${key}'`);
        pressedDirectionKeys.add(key);
        lastKeyToggleTime = now;
      }
    }
  }
}

// handle button presses (keeps your earlier behavior)
function handleButton(side, idx, down) {
  if (side === 'left') {
    if (idx === 0) {
      robot.mouseToggle(down ? 'down' : 'up', 'left');
      console.log(`🔘 ${side} Button ${idx + 1} ${down ? 'DOWN (LeftClick)' : 'UP'}`);
      return;
    } else if (idx === 1) {
      robot.mouseToggle(down ? 'down' : 'up', 'right');
      console.log(`🔘 ${side} Button ${idx + 1} ${down ? 'DOWN (RightClick)' : 'UP'}`);
      return;
    } else if (idx === 2) {
      robot.mouseToggle(down ? 'down' : 'up', 'middle');
      console.log(`🔘 ${side} Button ${idx + 1} ${down ? 'DOWN (MiddleClick)' : 'UP'}`);
      return;
    }
  }

  const key = BUTTON_MAPPING[side]?.[idx];
  if (key) {
    robot.keyToggle(key, down ? 'down' : 'up');
  }

  if (down) pressedButtons[side].add(idx);
  else pressedButtons[side].delete(idx);

  console.log(`🔘 ${side} Button ${idx + 1} ${down ? 'DOWN' : 'UP'} | aktuell: ${[...pressedButtons[side]].map(i => i + 1)}`);
}

// move mouse using accumulated fractional values and only if change exceeds threshold
function applyMouseMoveByVector(nx, ny, dtSec) {
  // Input nx,ny are normalized -1..1 for right-stick.
  // Use magnitude and sensitivity curve to compute pixel displacement per second.
  const mag = mag01(nx, ny);
  if (mag < DEADZONE && mag < DEADZONE_EXIT) return;

  // apply sensitivity curve on magnitude
  const scaledMag = Math.pow(mag, SENSITIVITY_CURVE);

  // base speed pixels per second (scaled by MAX_SPEED)
  // MAX_SPEED originally 80 (pixels per frame). Now we'll treat as pixels per second for better control.
  const basePixelsPerSec = MAX_SPEED * 30; // multiply so responsiveness feels similar; tweakable
  const speed = basePixelsPerSec * scaledMag;

  // direction unit
  const dir = normalize(nx, ny);
  const dx = dir[0] * speed * dtSec;
  const dy = dir[1] * speed * dtSec;

  // accumulate subpixel movement
  lastOutput.mousePosSub.x += dx;
  lastOutput.mousePosSub.y += dy;

  // only move if integer change
  const moveX = Math.trunc(lastOutput.mousePosSub.x);
  const moveY = Math.trunc(lastOutput.mousePosSub.y);
  if (Math.abs(moveX) >= 1 || Math.abs(moveY) >= 1) {
    const pos = robot.getMousePos();
    let tx = pos.x + moveX;
    let ty = pos.y + moveY;
    tx = Math.min(Math.max(0, tx), screenSize.width - 1);
    ty = Math.min(Math.max(0, ty), screenSize.height - 1);
    robot.moveMouse(tx, ty);
    // subtract applied integer portion
    lastOutput.mousePosSub.x -= moveX;
    lastOutput.mousePosSub.y -= moveY;
    // debug
    // console.log(`🖱️ moved by (${moveX},${moveY}) -> (${tx},${ty})`);
  }
}

// ---------- UDP server: store newest input per side ----------
const server = dgram.createSocket('udp4');

server.on('message', (msg, rinfo) => {
  try {
    const d = JSON.parse(msg.toString());
    const t = d.type;
    const side = d.side;
    const now = nowMs();

    if (t === 'move') {
      const x = Number(d.x || 0);
      const y = Number(d.y || 0);
      if (side === 'left' || side === 'right') {
        latestInput[side] = { x, y, ts: now };
      }
    } else if (t === 'button_down' || t === 'button_up') {
      const idx = d.index;
      if (idx !== undefined) {
        handleButton(side, idx, t === 'button_down');
      }
    } else if (t === 'config') {
      if (d.constants) {
        applyConfig(d.constants);
        const reply = JSON.stringify({
          type: 'config_ack',
          updatedConfig: dynamicConfig,
        });
        server.send(reply, rinfo.port, rinfo.address, (err) => {
          if (err) console.error('❌ Fehler beim Senden der Bestätigung:', err);
          else console.log(`✅ Config-Bestätigung an ${rinfo.address}:${rinfo.port} gesendet`);
        });
      }
    } else {
      console.warn('⚠️ Unbekannter Typ:', d);
    }
  } catch (e) {
    console.error('❌ Fehler beim Verarbeiten:', e);
  }
});

server.on('listening', () => {
  const address = server.address();
  const localIps = getAllLocalIPs();
  console.log(`🟢 UDP-Server läuft auf ${localIps.join(", ")}:${address.port} (warte auf Pakete...)`);
});

server.bind(UDP_PORT, '0.0.0.0');

// ---------- Main tick loop (fixed rate) ----------
function tick() {
  const now = process.hrtime.bigint();
  const dtNs = Number(now - lastTime);
  const dtSec = dtNs / 1e9;
  lastTime = now;

  // For each side, compute smoothed values using time-based exponential smoothing
  for (const side of ['left', 'right']) {
    const input = latestInput[side];
    // if input is stale, slowly decay to zero (lets sticks recentre)
    const ageMs = nowMs() - (input.ts || 0);
    let targetX = input.x, targetY = input.y;
    if (ageMs > 250) { // if no input for 250ms, treat as zero input
      targetX = 0;
      targetY = 0;
    }

    const alpha = smoothingAlpha(dtSec, SMOOTH_TIME);
    smoothed[side].x = smoothed[side].x * (1 - alpha) + targetX * alpha;
    smoothed[side].y = smoothed[side].y * (1 - alpha) + targetY * alpha;
  }

  // Anti-polarisation: limit how fast direction changes for left (keyboard) stick and right (mouse) stick separately.
  // We'll limit angle change between lastOutput and new smoothed direction.
  // Compute left stick direction change and apply angular rate limit.
  for (const side of ['left', 'right']) {
    const s = smoothed[side];
    const prev = side === 'left' ? lastOutput.leftAxes : lastOutput.rightAxes;
    // current and target angles
    const targetMag = mag01(s.x, s.y);
    let targetAngle = 0;
    if (targetMag > 0.0001) targetAngle = angleOf(s.x, s.y);
    const prevMag = mag01(prev.x, prev.y);
    let prevAngle = 0;
    if (prevMag > 0.0001) prevAngle = angleOf(prev.x, prev.y);

    // compute allowed angle change this tick
    const maxDeg = TURN_RATE_DEG_PER_SEC * dtSec;
    const maxRad = (maxDeg * Math.PI) / 180;

    let newAngle = targetAngle;
    if (prevMag > 0.0001 && targetMag > 0.0001) {
      const da = angleDiff(targetAngle, prevAngle);
      // clamp da to [-maxRad, maxRad]
      const clamped = clamp(da, -maxRad, maxRad);
      newAngle = prevAngle + clamped;
    } else if (prevMag > 0.0001 && targetMag <= 0.0001) {
      // decaying to zero: allow rotation toward zero gradually (no flip)
      const da = angleDiff(0, prevAngle);
      const clamped = clamp(da, -maxRad, maxRad);
      newAngle = prevAngle + clamped;
    } else {
      // prev zero, target non-zero -> can set target angle immediately
      newAngle = targetAngle;
    }

    // ramp magnitude towards target smoothly (avoid instant snap)
    // simple exponential approach:
    const magAlpha = smoothingAlpha(dtSec, SMOOTH_TIME * 0.8);
    const newMag = prevMag * (1 - magAlpha) + targetMag * magAlpha;

    // convert back to x,y
    const nx = newMag * Math.cos(newAngle);
    const ny = newMag * Math.sin(newAngle);

    if (side === 'left') lastOutput.leftAxes = { x: nx, y: ny };
    else lastOutput.rightAxes = { x: nx, y: ny };
  }

  // Apply left stick -> keyboard WASD
  {
    // Hysteresis deadzone: use DEADZONE to enter deadzone, DEADZONE_EXIT to leave
    const ax = lastOutput.leftAxes.x;
    const ay = lastOutput.leftAxes.y;
    const mag = mag01(ax, ay);
    let keys;
    if (mag < DEADZONE) {
      // inside deadzone: release keys
      keys = new Set();
    } else if (mag < DEADZONE_EXIT) {
      // keep previous keys (hysteresis)
      keys = mapDirectionToKeysFromAxes(lastOutput.leftAxes.x, lastOutput.leftAxes.y);
    } else {
      keys = mapDirectionToKeysFromAxes(ax, ay);
    }
    updatePressedDirectionKeys('left', keys);
  }

  // Apply right stick -> mouse movement
  {
    applyMouseMoveByVector(lastOutput.rightAxes.x, lastOutput.rightAxes.y, dtSec);
  }

  // schedule next tick
  setTimeout(tick, tickIntervalMs);
}

// start ticking
lastTime = process.hrtime.bigint();
setTimeout(tick, tickIntervalMs);

// ---------- Utility: IP discovery (unchanged) ----------
function getAllLocalIPs() {
  const ips = [];
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (
        net.family === 'IPv4' &&
        !net.internal &&
        !net.address.startsWith('169.254.')
      ) {
        ips.push(net.address);
      }
    }
  }
  return ips.length > 0 ? ips : ['127.0.0.1'];
}
