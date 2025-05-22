const dgram = require('dgram');
const robot = require('robotjs');
const os = require('os');

const UDP_PORT = 8080;
let MAX_SPEED = 80;
let DEADZONE = 0.1;
let SMOOTH_FACTOR = 0.3;
let MOVE_THROTTLE = 1000 / 60;

const LEFT_STICK_RELEASE_DELAY = 150;

const BUTTON_MAPPING = {
    left: { 0: 'space', 1: 'shift' },
    right: { 0: 'enter', 1: 'tab' },
};

let dynamicConfig = {
    MAX_SPEED,
    DEADZONE,
    SMOOTH_FACTOR,
    MOVE_THROTTLE,
};

function applyConfig(updates) {
    if (typeof updates !== 'object') return;
    for (const [key, value] of Object.entries(updates)) {
        if (dynamicConfig.hasOwnProperty(key) && typeof value === 'number') {
            dynamicConfig[key] = value;
            console.log(`🛠️ ${key} wurde aktualisiert: ${value}`);
        }
    }
    MAX_SPEED = dynamicConfig.MAX_SPEED;
    DEADZONE = dynamicConfig.DEADZONE;
    SMOOTH_FACTOR = dynamicConfig.SMOOTH_FACTOR;
    MOVE_THROTTLE = dynamicConfig.MOVE_THROTTLE;

    console.log('🔧 Aktuelle Konfiguration:', dynamicConfig);
}

let pressedButtons = { left: new Set(), right: new Set() };
let lastMoveTime = 0;
let lastLeftX = 0;
let lastLeftY = 0;
let pressedDirectionKeys = new Set();
const screenSize = robot.getScreenSize();

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

function smoothInput(newX, newY) {
    lastLeftX = (1 - SMOOTH_FACTOR) * lastLeftX + SMOOTH_FACTOR * newX;
    lastLeftY = (1 - SMOOTH_FACTOR) * lastLeftY + SMOOTH_FACTOR * newY;
    return [lastLeftX, lastLeftY];
}

function mapDirectionToKeys(x, y) {
    const keys = new Set();
    if (y < -DEADZONE) keys.add('w');
    if (y > DEADZONE) keys.add('s');
    if (x < -DEADZONE) keys.add('a');
    if (x > DEADZONE) keys.add('d');
    return keys;
}

function updatePressedDirectionKeys(side, newKeys) {
    for (const key of pressedDirectionKeys) {
        if (!newKeys.has(key)) {
            robot.keyToggle(key, 'up');
            console.log(`⬆️ ${side} lässt '${key}' los`);
            pressedDirectionKeys.delete(key);
        }
    }
    for (const key of newKeys) {
        if (!pressedDirectionKeys.has(key)) {
            robot.keyToggle(key, 'down');
            console.log(`⬇️ ${side} drückt '${key}'`);
            pressedDirectionKeys.add(key);
        }
    }
}

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

function handleMouseMove(x, y) {
    const now = Date.now();
    if (now - lastMoveTime < MOVE_THROTTLE) return;
    lastMoveTime = now;

    const mag = Math.hypot(x, y);
    if (mag < DEADZONE) return;

    const nx = x / mag;
    const ny = y / mag;
    const speed = mag * MAX_SPEED;

    const pos = robot.getMousePos();
    let tx = pos.x + nx * speed;
    let ty = pos.y + ny * speed;

    tx = Math.min(Math.max(0, tx), screenSize.width - 1);
    ty = Math.min(Math.max(0, ty), screenSize.height - 1);

    robot.moveMouse(tx, ty);
    console.log(`🖱️ Maus zu (${tx.toFixed(1)},${ty.toFixed(1)}) @ speed ${speed.toFixed(1)}`);
}

const server = dgram.createSocket('udp4');

server.on('message', (msg, rinfo) => {
    try {
        const d = JSON.parse(msg.toString());
        const t = d.type;
        const side = d.side;

        if (t === 'move') {
            const x = d.x || 0;
            const y = d.y || 0;

            if (side === 'left') {
                const mag = Math.hypot(x, y);
                if (mag < DEADZONE) {
                    updatePressedDirectionKeys(side, new Set());
                    lastLeftX = 0;
                    lastLeftY = 0;
                    return;
                }
                const [x_s, y_s] = smoothInput(x, y);
                const keys = mapDirectionToKeys(x_s, y_s);
                updatePressedDirectionKeys(side, keys);
            } else if (side === 'right') {
                handleMouseMove(x, y);
            }

        } else if (t === 'button_down' || t === 'button_up') {
            const idx = d.index;
            if (idx !== undefined) {
                handleButton(side, idx, t === 'button_down');
            }

        } else if (t === 'config') {
            if (d.constants) {
                applyConfig(d.constants);

                // ⬅️ Neue Antwort an Client mit aktualisierter Konfiguration
                const reply = JSON.stringify({
                    type: 'config_ack',
                    updatedConfig: dynamicConfig,
                });

                server.send(reply, rinfo.port, rinfo.address, (err) => {
                    if (err) {
                        console.error('❌ Fehler beim Senden der Bestätigung:', err);
                    } else {
                        console.log(`✅ Config-Bestätigung an ${rinfo.address}:${rinfo.port} gesendet`);
                    }
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

