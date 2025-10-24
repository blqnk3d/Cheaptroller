// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const gamepad = require('./build/Release/gamepad.node');
const logger = require('./logger');
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
let shuttingDown = false;

// ---------- Initialize Gamepad ----------
try {
    gamepad.create();
    logger.info('🎮 Gamepad initialized');
} catch (err) {
    logger.error('❌ Failed to initialize gamepad native module:', err);
    // If the native module can't be initialized, abort early to avoid undefined behavior
    process.exit(1);
}

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
    // Avoid logging every UDP message - only warn on parse/validation errors.
    let d;
    try {
        d = JSON.parse(msg.toString());
    } catch (e) {
        logger.warn('⚠️ UDP message is not JSON, ignoring from %s : %s', rinfo.address, msg.toString());
        return;
    }

    const { type: t, side, index } = d || {};
    if (!t) {
        logger.warn('⚠️ UDP message missing `type`, ignoring from %s', rinfo.address);
        return;
    }

    // 🕹 Stick movement
    if (t === 'move' && (side === 'left' || side === 'right')) {
        const x = Math.round((d.x || 0) * 32767);
        const y = Math.round((d.y || 0) * 32767);
        try {
            gamepad.moveStick(side, x, y);
        } catch (err) {
            logger.error('❌ Error moving stick: %o', err);
        }
        return;
    }

    // 🔘 Button press/release
    else if (t === 'button_down' || t === 'button_up') {
        const pressed = t === 'button_down';

        // normalize index (UDP senders may send strings)
        const idx = typeof index === 'string' ? parseInt(index, 10) : index;
        if (!Number.isInteger(idx)) {
            logger.warn('⚠️ button event with invalid index from %s : %s', rinfo.address, index);
            return;
        }

        // Check if it's a normal button
        const buttonStr = BUTTON_MAP[idx];
        if (buttonStr) {
            try {
                gamepad.pressButton(buttonStr, pressed);
            } catch (err) {
                logger.error('❌ Error pressing button %s: %o', buttonStr, err);
            }
            return;
        }

        // Check if it's a D-Pad button
        const dpadDir = DPAD_MAP[idx];
        if (dpadDir) {
            // Send D-Pad as discrete BTN_DPAD_* key events via the native module
            // gamepad.cpp maps "Up"/"Down"/"Left"/"Right" -> BTN_DPAD_*
            const capitalized = dpadDir[0].toUpperCase() + dpadDir.slice(1);
            try {
                gamepad.pressButton(capitalized, pressed);
            } catch (err) {
                logger.error('❌ Error pressing dpad button %s: %o', capitalized, err);
            }
            return;
        }

        logger.warn('⚠️ Unknown button index from %s : %s', rinfo.address, idx);
        return;
    }

    // 🌐 Misc events
    else if (t === 'config' && d.constants) {
        logger.info('⚡ Ignored config from UDP: %s', rinfo.address);
    } else if (t === 'ip_update' && d.ip) {
        logger.info('🌐 Received IP update from %s: %s', rinfo.address, d.ip);
    }
});

// UDP error handler
udpServer.on('error', (err) => {
    logger.error('❌ UDP server error: %o', err);
    try {
        udpServer.close();
    } catch (e) {
        // ignore
    }
});

// ---------- UDP Start ----------
function startUdpServer(port = UDP_PORT) {
    udpServer.bind(port, '0.0.0.0', () =>
        logger.info('🟢 UDP running on %s', port)
    );
}

// ---------- Socket.IO ----------
function initSocketIO(httpServer) {
    ioInstance = new Server(httpServer);

    ioInstance.on('connection', (socket) => {
        console.log('🔌 Web client connected');

        // Emit status immediately and then on an interval. Keep the interval id so
        // we can clear it when the socket disconnects (avoids runaway timers).
        const emitStatus = () => {
            const config = getDynamicConfig();
            const allowFrontendConfig = getAllowFrontendConfig();
            socket.emit('status', {
                ...getStatus(),
                config,
                allowFrontendConfig
            });
        };

        emitStatus();
        // Compute a reasonable default tick (don't allow too-fast intervals)
        const initialTick = (getDynamicConfig() && getDynamicConfig().TICK_RATE) || 10;
        const statusIntervalMs = Math.max(50, Math.round(1000 / initialTick));
        const statusInterval = setInterval(emitStatus, statusIntervalMs);

        socket.on('disconnect', () => {
            clearInterval(statusInterval);
            console.log('🔌 Web client disconnected');
        });

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

function shutdown(signal) {
    if (shuttingDown) {
        console.log('🛑 Shutdown already in progress, forcing exit');
        try { process.exit(1); } catch (e) {}
        return;
    }
    shuttingDown = true;
    console.log('🛑 Shutting down', signal || '');

    try {
        udpServer.close();
    } catch (e) {}

    if (ioInstance && typeof ioInstance.close === 'function') {
        try {
            ioInstance.close();
        } catch (e) {
            console.error('Error closing Socket.IO:', e);
        }
    }

    try {
        gamepad.close();
    } catch (e) {
        console.error('Error closing gamepad:', e);
    }

    // If cleanup doesn't exit the process within a short time, force exit
    setTimeout(() => {
        console.log('🛑 Forcing process exit');
        try { process.exit(0); } catch (e) {}
    }, 1000);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('exit', () => {
    try { gamepad.close(); } catch (e) {}
});

module.exports = {
    startUdpServer,
    initSocketIO,
    UDP_PORT
};

// Stop/cleanup function to allow external shutdown orchestration
function stopUdpServer() {
    try {
        udpServer.close();
    } catch (e) {}

    if (ioInstance && typeof ioInstance.close === 'function') {
        try {
            ioInstance.close();
        } catch (e) {
            console.error('Error closing Socket.IO in stopUdpServer:', e);
        }
    }

    try {
        gamepad.close();
    } catch (e) {}
}

module.exports.stopUdpServer = stopUdpServer;
