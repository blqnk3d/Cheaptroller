// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const gamepad = require('./build/Release/gamepad.node');
const {
    getStatus,
    getDynamicConfig,
    getAllowFrontendConfig,
    setAllowFrontendConfig,
    applyConfig
} = require('./config');

// UDP
const UDP_PORT = 8080;
let ioInstance = null;

// ---------- Initialize Gamepad ----------
gamepad.create();
console.log('🎮 Gamepad initialized');

// ---------- UDP Server ----------
const udpServer = dgram.createSocket('udp4');

// Button mapping (main buttons)
const BUTTON_MAP = {
    0: 'A',
    1: 'B',
    2: 'X',
    3: 'Y',
    4: 'LB',
    5: 'RB',
    6: 'Select',
    7: 'Start',
    8: 'LStick',
    9: 'RStick'
};

// D-Pad mapping (for button indices)
const DPAD_MAP = {
    10: 'up',
    11: 'down',
    12: 'left',
    13: 'right'
};

// Keep track of current D-Pad state
let dpadX = 0;
let dpadY = 0;

// ---------- UDP Message Handling ----------
udpServer.on('message', (msg, rinfo) => {

    let d;
    try {
        d = JSON.parse(msg.toString());
    } catch (e) {
        console.warn('⚠️ UDP message is not JSON, ignoring:', msg.toString());
        return;
    }

    const { type: t, side, index } = d;

    // 🕹 Stick movement
    if (t === 'move' && (side === 'left' || side === 'right')) {
        const x = Math.round((d.x || 0) * 32767);
        const y = Math.round((d.y || 0) * 32767);
        try {
            gamepad.moveStick(side, x, y);
        } catch (err) {
            console.error('❌ Error moving stick:', err);
        }
    }

    // 🔘 Button press/release
    else if (t === 'button_down' || t === 'button_up') {
        const pressed = t === 'button_down';

        // Check if it's a normal button
        let buttonStr = BUTTON_MAP[index];

        if (buttonStr) {
            try {
                gamepad.pressButton(buttonStr, pressed);
            } catch (err) {
                console.error(`❌ Error pressing button ${buttonStr}:`, err);
            }
        }

        // Check if it's a D-Pad button
        else if (DPAD_MAP[index]) {
            const dir = DPAD_MAP[index];

            if (dir === 'up') dpadY = pressed ? -1 : (dpadY === -1 ? 0 : dpadY);
            if (dir === 'down') dpadY = pressed ? 1 : (dpadY === 1 ? 0 : dpadY);
            if (dir === 'left') dpadX = pressed ? -1 : (dpadX === -1 ? 0 : dpadX);
            if (dir === 'right') dpadX = pressed ? 1 : (dpadX === 1 ? 0 : dpadX);

            try {
                gamepad.moveDpad(dpadX, dpadY);
            } catch (err) {
                console.error(`❌ Error moving dpad:`, err);
            }
        }

        else {
            console.warn('⚠️ Unknown button index:', index);
        }
    }

    // 🌐 Misc events
    else if (t === 'config' && d.constants) {
        console.log('⚡ Ignored config from UDP:', rinfo.address);
    } else if (t === 'ip_update' && d.ip) {
        console.log(`🌐 Received IP update from ${rinfo.address}: ${d.ip}`);
    }
});

// ---------- UDP Start ----------
function startUdpServer(port = UDP_PORT) {
    udpServer.bind(port, '0.0.0.0', () =>
        console.log(`🟢 UDP running on ${port}`)
    );
}

// ---------- Socket.IO ----------
function initSocketIO(httpServer) {
    ioInstance = new Server(httpServer);

    ioInstance.on('connection', (socket) => {
        console.log('🔌 Web client connected');

        const sendStatus = () => {
            const config = getDynamicConfig();
            const allowFrontendConfig = getAllowFrontendConfig();
            socket.emit('status', {
                ...getStatus(),
                config,
                allowFrontendConfig
            });

            const tickIntervalMs = Math.round(1000 / config.TICK_RATE);
            setTimeout(sendStatus, tickIntervalMs);
        };
        sendStatus();

        socket.on('config', (newConfig) => {
            if (getAllowFrontendConfig()) {
                applyConfig(newConfig);
            }
        });

        socket.on('toggleFrontendConfig', (state) => {
            setAllowFrontendConfig(!!state);
        });
    });

    return ioInstance;
}

// ---------- Graceful Shutdown ----------
process.on('exit', () => gamepad.close());
process.on('SIGINT', () => process.exit());

module.exports = {
    startUdpServer,
    initSocketIO,
    UDP_PORT
};
