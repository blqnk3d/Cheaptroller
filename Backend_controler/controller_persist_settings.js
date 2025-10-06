// controller_server.js
const dgram = require('dgram');
const robot = require('robotjs');
const os = require('os');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');

const UDP_PORT = 8080;
const WEB_PORT = 3000;
const SETTINGS_FILE = path.join(__dirname, 'controller_config.json');

// ---------- Configurable parameters ----------
let dynamicConfig = {
    MAX_SPEED: 80,
    DEADZONE: 0.05,
    DEADZONE_EXIT: 0.035,
    SMOOTH_TIME: 0.06,
    TICK_RATE: 60,
    TURN_RATE_DEG_PER_SEC: 720,
    SENSITIVITY_CURVE: 1.0
};

// ---------- Load persisted settings ----------
if (fs.existsSync(SETTINGS_FILE)) {
    try {
        const data = JSON.parse(fs.readFileSync(SETTINGS_FILE));
        Object.assign(dynamicConfig, data);
        console.log('⚡ Loaded persisted config:', dynamicConfig);
    } catch (e) {
        console.error('❌ Failed to load persisted config:', e);
    }
}

// ---------- State ----------
let lastTime = process.hrtime.bigint();
let tickIntervalMs = Math.round(1000 / dynamicConfig.TICK_RATE);

let latestInput = { left: { x: 0, y: 0, ts: 0 }, right: { x: 0, y: 0, ts: 0 } };
let smoothed = { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } };
let lastOutput = { leftAxes: { x: 0, y: 0 }, rightAxes: { x: 0, y: 0 }, mousePosSub: { x: 0, y: 0 } };
let pressedButtons = { left: new Set(), right: new Set() };
let pressedDirectionKeys = new Set();
let lastKeyToggleTime = 0;

let screenSize, mousePos;
try {
    screenSize = robot.getScreenSize();
    mousePos = robot.getMousePos();
} catch (e) {
    console.error('❌ RobotJS failed:', e);
    screenSize = { width: 1920, height: 1080 };
    mousePos = { x: 960, y: 540 };
}

// Toggle for frontend config
let ALLOW_FRONTEND_CONFIG = true; // start with enabled for demo

// ---------- Helpers ----------
const nowMs = () => Number(process.hrtime.bigint()) / 1e6;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const magnitude = (x, y) => Math.hypot(x, y);
const normalize = (x, y) => {
    const m = magnitude(x, y);
    return m ? [x / m, y / m] : [0, 0];
};
const mag01 = (x, y) => clamp(magnitude(x, y), 0, 1);
const smoothingAlpha = (dtSec, tauSec) =>
    tauSec <= 0 ? 1.0 : 1 - Math.exp(-dtSec / tauSec);
const angleOf = (x, y) => Math.atan2(y, x);
const angleDiff = (a, b) => {
    let d = a - b;
    while (d <= -Math.PI) d += 2 * Math.PI;
    while (d > Math.PI) d -= 2 * Math.PI;
    return d;
};

// ---------- Config helpers ----------
function applyConfig(updates, persist = true) {
    if (typeof updates !== 'object') return;
    for (const [k, v] of Object.entries(updates))
        if (dynamicConfig.hasOwnProperty(k) && typeof v === 'number')
            dynamicConfig[k] = v;
    tickIntervalMs = Math.round(1000 / dynamicConfig.TICK_RATE);
    if (persist) saveConfig();
    console.log('🔧 Config applied:', dynamicConfig);
}

function saveConfig() {
    try {
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(dynamicConfig, null, 2));
    } catch (e) {
        console.error('❌ Failed to save config:', e);
    }
}

// ---------- Input / Buttons ----------
function mapDirectionToKeysFromAxes(ax, ay) {
    const keys = new Set();
    if (ay < -dynamicConfig.DEADZONE) keys.add('w');
    else if (ay > dynamicConfig.DEADZONE) keys.add('s');
    if (ax < -dynamicConfig.DEADZONE) keys.add('a');
    else if (ax > dynamicConfig.DEADZONE) keys.add('d');
    return keys;
}

function updatePressedDirectionKeys(side, newKeys) {
    const now = nowMs();
    for (const key of Array.from(pressedDirectionKeys))
        if (!newKeys.has(key) && now - lastKeyToggleTime > 30) {
            robot.keyToggle(key, 'up');
            pressedDirectionKeys.delete(key);
            lastKeyToggleTime = now;
        }
    for (const key of newKeys)
        if (!pressedDirectionKeys.has(key) && now - lastKeyToggleTime > 30) {
            robot.keyToggle(key, 'down');
            pressedDirectionKeys.add(key);
            lastKeyToggleTime = now;
        }
}

function handleButton(side, idx, down) {
    if (side === 'left') {
        if (idx === 0) {
            robot.mouseToggle(down ? 'down' : 'up', 'left');
            return;
        }
        if (idx === 1) {
            robot.mouseToggle(down ? 'down' : 'up', 'right');
            return;
        }
        if (idx === 2) {
            robot.mouseToggle(down ? 'down' : 'up', 'middle');
            return;
        }
    }
    const key = { right: { 0: 'enter', 1: 'tab' } }[side]?.[idx];
    if (key) robot.keyToggle(key, down ? 'down' : 'up');
    if (down) pressedButtons[side].add(idx);
    else pressedButtons[side].delete(idx);
}

function applyMouseMoveByVector(nx, ny, dtSec) {
    const mag = mag01(nx, ny);
    if (mag < dynamicConfig.DEADZONE && mag < dynamicConfig.DEADZONE_EXIT) return;
    const scaledMag = Math.pow(mag, dynamicConfig.SENSITIVITY_CURVE);
    const speed = dynamicConfig.MAX_SPEED * 30 * scaledMag;
    const [dirX, dirY] = normalize(nx, ny);
    lastOutput.mousePosSub.x += dirX * speed * dtSec;
    lastOutput.mousePosSub.y += dirY * speed * dtSec;
    const moveX = Math.trunc(lastOutput.mousePosSub.x);
    const moveY = Math.trunc(lastOutput.mousePosSub.y);
    if (moveX !== 0 || moveY !== 0) {
        mousePos.x = clamp(mousePos.x + moveX, 0, screenSize.width - 1);
        mousePos.y = clamp(mousePos.y + moveY, 0, screenSize.height - 1);
        robot.moveMouse(mousePos.x, mousePos.y);
        lastOutput.mousePosSub.x -= moveX;
        lastOutput.mousePosSub.y -= moveY;
    }
}

// ---------- UDP Server ----------
const udpServer = dgram.createSocket('udp4');
udpServer.on('message', (msg, rinfo) => {
    try {
        const d = JSON.parse(msg.toString());
        const t = d.type,
            side = d.side,
            now = nowMs();
        if (t === 'move') {
            const x = Number(d.x || 0),
                y = Number(d.y || 0);
            if (side === 'left' || side === 'right')
                latestInput[side] = { x, y, ts: now };
        } else if (t === 'button_down' || t === 'button_up') {
            handleButton(side, d.index, t === 'button_down');
        } else if (t === 'config' && d.constants) {
            applyConfig(d.constants);
            udpServer.send(
                JSON.stringify({ type: 'config_ack', updatedConfig: dynamicConfig }),
                rinfo.port,
                rinfo.address
            );
        }
    } catch (e) {
        console.error('❌ UDP parse error:', e);
    }
});
udpServer.bind(UDP_PORT, '0.0.0.0', () =>
    console.log(`🟢 UDP running on ${UDP_PORT}`)
);

// ---------- Web Server ----------
const app = express();
const httpServer = http.createServer(app);
const io = new Server(httpServer);

app.use(express.static('public'));
app.use(express.json());

// Save config from frontend
app.post('/api/config', (req, res) => {
    if (ALLOW_FRONTEND_CONFIG) {
        applyConfig(req.body);
        res.json({ success: true, config: dynamicConfig });
    } else {
        res.json({ success: false, reason: 'Frontend config disabled' });
    }
});

// Return current status and config
app.get('/api/status', (req, res) => {
    res.json({
        leftAxes: lastOutput.leftAxes,
        rightAxes: lastOutput.rightAxes,
        mousePos,
        pressedKeys: Array.from(pressedDirectionKeys),
        pressedButtons,
        config: dynamicConfig,
        allowFrontendConfig: ALLOW_FRONTEND_CONFIG,
    });
});

io.on('connection', (socket) => {
    console.log('🔌 Web client connected');

    // Send periodic status updates
    const sendStatus = () => {
        socket.emit('status', {
            leftAxes: lastOutput.leftAxes,
            rightAxes: lastOutput.rightAxes,
            mousePos,
            pressedKeys: Array.from(pressedDirectionKeys),
            pressedButtons,
            config: dynamicConfig,
            allowFrontendConfig: ALLOW_FRONTEND_CONFIG,
        });
        setTimeout(sendStatus, tickIntervalMs);
    };
    sendStatus();

    socket.on('config', (newConfig) => {
        if (ALLOW_FRONTEND_CONFIG) applyConfig(newConfig);
    });

    socket.on('toggleFrontendConfig', (state) => {
        ALLOW_FRONTEND_CONFIG = !!state;
        console.log('⚡ ALLOW_FRONTEND_CONFIG =', ALLOW_FRONTEND_CONFIG);
    });
});

httpServer.listen(WEB_PORT, () =>
    console.log(`🌐 Web server running on http://localhost:${WEB_PORT}`)
);

// ---------- Main tick loop ----------
function tick() {
    const now = process.hrtime.bigint();
    const dtSec = Number(now - lastTime) / 1e9;
    lastTime = now;

    const alpha = smoothingAlpha(dtSec, dynamicConfig.SMOOTH_TIME),
        magAlpha = smoothingAlpha(dtSec, dynamicConfig.SMOOTH_TIME * 0.8);

    ['left', 'right'].forEach((side) => {
        let input = latestInput[side];
        if (nowMs() - input.ts > 250) input = { x: 0, y: 0 };
        const s = smoothed[side];
        s.x = s.x * (1 - alpha) + input.x * alpha;
        s.y = s.y * (1 - alpha) + input.y * alpha;

        const prev = side === 'left' ? lastOutput.leftAxes : lastOutput.rightAxes;
        const prevMag = mag01(prev.x, prev.y),
            targetMag = mag01(s.x, s.y);
        const targetAngle = targetMag > 0 ? angleOf(s.x, s.y) : 0,
            prevAngle = prevMag > 0 ? angleOf(prev.x, prev.y) : 0;
        const maxRad = (dynamicConfig.TURN_RATE_DEG_PER_SEC * dtSec * Math.PI) / 180;
        let newAngle =
            prevMag > 0 && targetMag > 0
                ? prevAngle + clamp(angleDiff(targetAngle, prevAngle), -maxRad, maxRad)
                : prevMag > 0 && targetMag <= 0
                ? prevAngle + clamp(angleDiff(0, prevAngle), -maxRad, maxRad)
                : targetAngle;
        const newMag = prevMag * (1 - magAlpha) + targetMag * magAlpha;
        const nx = newMag * Math.cos(newAngle),
            ny = newMag * Math.sin(newAngle);
        if (side === 'left') lastOutput.leftAxes = { x: nx, y: ny };
        else lastOutput.rightAxes = { x: nx, y: ny };
    });

    const ax = lastOutput.leftAxes.x,
        ay = lastOutput.leftAxes.y;
    const mag = mag01(ax, ay);
    const keys = mag < dynamicConfig.DEADZONE ? new Set() : mapDirectionToKeysFromAxes(ax, ay);
    updatePressedDirectionKeys('left', keys);

    applyMouseMoveByVector(lastOutput.rightAxes.x, lastOutput.rightAxes.y, dtSec);

    const next = tickIntervalMs - (Number(process.hrtime.bigint() - now) / 1e6);
    setTimeout(tick, Math.max(0, next));
}

lastTime = process.hrtime.bigint();
setTimeout(tick, tickIntervalMs);

// ---------- Utility ----------
function getAllLocalIPs() {
    const ips = [];
    for (const name of Object.keys(os.networkInterfaces()))
        for (const net of os.networkInterfaces()[name])
            if (net.family === 'IPv4' && !net.internal && !net.address.startsWith('169.254.'))
                ips.push(net.address);
    return ips.length > 0 ? ips : ['127.0.0.1'];
}
