// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const gamepad = require('./gamepad.node');
const logger = require('./logger');

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

// D-Pad mapping (fixed - match client indices: 10=left,11=right,12=up,13=down)
const DPAD_MAP = {
    10: 'up',
    11: 'down',
    12: 'left',
    13: 'right'
};

// track D-Pad pressed state so simultaneous presses work
const dpadState = { up: false, down: false, left: false, right: false };

// UDP message handling
udpServer.on('message', (msg, rinfo) => {


    logger.debug('UDP message from %s:%d: %s', rinfo.address, rinfo.port, msg.toString());

    let d;
    try {
        d = JSON.parse(msg.toString());
    } catch (e) {
        logger.warn('UDP message not JSON from %s: %s', rinfo.address, msg.toString());
        return;
    }

    const { type: t, side, index, x, y } = d || {};
    if (!t) return;

    if (t === 'move' && (side === 'left' || side === 'right')) {
        try {
            gamepad.moveStick(side, Math.round((x || 0) * 32767), Math.round((y || 0) * 32767));
        } catch (err) {
            logger.error('Error moving stick: %o', err);
        }
        return;
    }

    if (t === 'button_down' || t === 'button_up') {
        const pressed = t === 'button_down';
        const idx = typeof index === 'string' ? parseInt(index, 10) : index;
        if (!Number.isInteger(idx)) return;

        const buttonStr = BUTTON_MAP[idx];
        if (buttonStr) {
            try {
                logger.debug('Button index %d -> %s (pressed=%s) from %s', idx, buttonStr, pressed, rinfo.address);
                gamepad.pressButton(buttonStr, pressed);
            } catch (err) {
                logger.error('Error pressing button %s: %o', buttonStr, err);
            }
            return;
        }

        const dpadDir = DPAD_MAP[idx];
        if (dpadDir) {
            logger.debug('DPad index %d -> %s (pressed=%s) from %s', idx, dpadDir, pressed, rinfo.address);

            // update state and send digital D-Pad via moveDpad(x,y)
            dpadState[dpadDir] = pressed;
            const x = dpadState.left ? -1 : dpadState.right ? 1 : 0;
            const y = dpadState.up ? -1 : dpadState.down ? 1 : 0;
            try {
                gamepad.moveDpad(x, y);
            } catch (err) {
                logger.error('Error moving dpad %s: %o', dpadDir, err);
            }
            return;
        }

        logger.warn('Unknown button index from %s: %s', rinfo.address, idx);
        return;
    }

    if (t === 'ip_update' && d.ip) {
        logger.info('Received IP update from %s: %s', rinfo.address, d.ip);
    }
});

// UDP error handler
udpServer.on('error', (err) => {
    logger.error('UDP server error: %o', err);
    try { udpServer.close(); } catch (e) {}
});

// Start UDP
function startUdpServer(port = UDP_PORT) {
    udpServer.bind(port, '0.0.0.0', () =>
        logger.info('UDP running on %s', port)
    );
}

// Socket.IO
function initSocketIO(httpServer) {
    ioInstance = new Server(httpServer);

    ioInstance.on('connection', (socket) => {
        console.log('Web client connected');

        socket.on('disconnect', () => {
            console.log('Web client disconnected');
        });
    });

    return ioInstance;
}

// Shutdown
function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log('Shutting down', signal || '');

    try { udpServer.close(); } catch (e) {}
    if (ioInstance && typeof ioInstance.close === 'function') {
        try { ioInstance.close(); } catch (e) { console.error('Error closing Socket.IO:', e); }
    }
    try { gamepad.close(); } catch (e) { console.error('Error closing gamepad:', e); }

    setTimeout(() => {
        console.log('Forcing process exit');
        try { process.exit(0); } catch (e) {}
    }, 1000);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('exit', () => { try { gamepad.close(); } catch (e) {} });

// Export
module.exports = {
    startUdpServer,
    initSocketIO,
    UDP_PORT,
    stopUdpServer: () => {
        try { udpServer.close(); } catch (e) {}
        if (ioInstance && typeof ioInstance.close === 'function') {
            try { ioInstance.close(); } catch (e) { console.error('Error closing Socket.IO in stopUdpServer:', e); }
        }
        try { gamepad.close(); } catch (e) {}
    }
};
