// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const { updateLatestInput, handleButton, getStatus } = require('./inputHandler');
const { applyConfig, getDynamicConfig, getAllowFrontendConfig, setAllowFrontendConfig } = require('./config');

const UDP_PORT = 8080;

let ioInstance = null;

// ---------- UDP Server ----------
const udpServer = dgram.createSocket('udp4');
udpServer.on('message', (msg, rinfo) => {
    try {
        const d = JSON.parse(msg.toString());
        const t = d.type,
            side = d.side;

        if (t === 'move') {
            const x = Number(d.x || 0),
                y = Number(d.y || 0);
            if (side === 'left' || side === 'right') updateLatestInput(side, x, y);
        } else if (t === 'button_down' || t === 'button_up') {
            handleButton(side, d.index, t === 'button_down');
        } else if (t === 'config' && d.constants) {
            // Ignore config from UDP entirely
            console.log('⚡ Ignored config from UDP:', rinfo.address);
        }
    } catch (e) {
        console.error('❌ UDP parse error:', e);
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

        // Initial and continuous status send
        const sendStatus = () => {
            const config = getDynamicConfig();
            const allowFrontendConfig = getAllowFrontendConfig();
            socket.emit('status', {
                ...getStatus(),
                config,
                allowFrontendConfig
            });

            // Re-schedule based on current TICK_RATE
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

module.exports = {
    startUdpServer,
    initSocketIO,
    UDP_PORT
};