// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const gamepad = require('./build/Release/gamepad.node');
const { getStatus, getDynamicConfig, getAllowFrontendConfig, setAllowFrontendConfig, applyConfig } = require('./config');

// UDP
const UDP_PORT = 8080;
let ioInstance = null;

// ---------- Initialize Gamepad ----------
gamepad.create();
console.log('🎮 Gamepad initialized');

// ---------- UDP Server ----------
const udpServer = dgram.createSocket('udp4');
// Map für Buttons (anpassen je nach deinem Gamepad-Addon)
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

// ---------- UDP Server ----------
udpServer.on('message', (msg, rinfo) => {
    let d;
    try {
        d = JSON.parse(msg.toString());
    } catch (e) {
        console.warn('⚠️ UDP message is not JSON, ignoring:', msg.toString());
        return;
    }

    const { type: t, side } = d;
    if (t === 'move' && (side === 'left' || side === 'right')) {
        const x = Math.round((d.x || 0) * 32767);
        const y = Math.round((d.y || 0) * 32767);

        try {
            // Muss exakt "left" oder "right" sein!
            gamepad.moveStick(side, x, y);
        } catch (err) {
            console.error('❌ Error moving stick:', err);
        }
    }
    else if (t === 'button_down' || t === 'button_up') {
        const pressed = t === 'button_down';
        const buttonStr = BUTTON_MAP[d.index];
        if (!buttonStr) {
            console.warn('⚠️ Unknown button index:', d.index);
            return;
        }
        try {
            gamepad.pressButton(buttonStr, pressed);
        } catch (err) {
            console.error('❌ Error pressing button:', err);
        }
    } else if (t === 'config' && d.constants) {
        console.log('⚡ Ignored config from UDP:', rinfo.address);
    } else if (t === 'ip_update' && d.ip) {
        console.log(`🌐 Received IP update from ${rinfo.address}: ${d.ip}`);
    }
});


function startUdpServer(port = UDP_PORT) {
    udpServer.bind(port, '0.0.0.0', () => console.log(`🟢 UDP running on ${port}`));
}

// ---------- Socket.io ----------
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

// Graceful shutdown
process.on('exit', () => gamepad.close());
process.on('SIGINT', () => process.exit());

module.exports = {
    startUdpServer,
    initSocketIO,
    UDP_PORT
};
