// udpWebSocket.js
const dgram = require('dgram');
const { Server } = require('socket.io');
const gamepad = require('./gamepad.node');
const logger = require('./logger');

// UDP
const UDP_PORT = 8080;
let ioInstance = null;
let shuttingDown = false;

// Performance optimization: cache stick values to avoid redundant updates
const stickState = { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } };
const STICK_DEADZONE = 0.00;  // Prevents stick drift (8% deadzone)

// Button state cache - use array for O(1) lookups instead of Map with string keys
const buttonState = new Array(14).fill(false);

// Pre-compiled DPAD set for O(1) lookup
const DPAD_INDICES = new Set([10, 11, 12, 13]);

// High-priority buttons (fastest response needed)
const PRIORITY_BUTTONS = new Set([0, 1, 2, 3]);  // A, B, X, Y - main action buttons

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
    6: 'LStick',
    7: 'RStick',
    8: 'Select',
    9: 'Start',
};

// D-Pad mapping (fixed - match client indices: 10=left,11=right,12=up,13=down)
const DPAD_MAP = {
    10: 'up',
    11: 'down',
    12: 'left',
    13: 'right'
};

// D-Pad direction cache for faster lookups (avoids object property access)
const DPAD_DIRECTIONS = ['', '', '', '', '', '', '', '', '', '', 'up', 'down', 'left', 'right'];

// track D-Pad pressed state so simultaneous presses work
const dpadState = { up: false, down: false, left: false, right: false };

// UDP message handling with optimized path for speed
udpServer.on('message', (msg, rinfo) => {
    let d;
    try {
        // Optimize: parse buffer directly (slightly faster than toString())
        d = JSON.parse(msg);
    } catch (e) {
        logger.warn('UDP message not JSON from %s', rinfo.address);
        return;
    }

    const { type: t, side, index, x, y } = d || {};
    if (!t) return;

    // Fast path: Stick movement (most frequent input)
    if (t === 'move' && (side === 'left' || side === 'right')) {
        // Apply deadzone to prevent stick drift
        let xVal = Math.abs(x || 0) < STICK_DEADZONE ? 0 : x || 0;
        let yVal = Math.abs(y || 0) < STICK_DEADZONE ? 0 : y || 0;
        
        // Only send if values actually changed (avoid redundant gamepad calls)
        const stickCache = stickState[side];
        if (stickCache.x !== xVal || stickCache.y !== yVal) {
            stickCache.x = xVal;
            stickCache.y = yVal;
            gamepad.moveStick(side, Math.round(xVal * 32767), Math.round(yVal * 32767));
        }
        return;
    }

    // Button handling - optimized fast path
    if (t === 'button_down' || t === 'button_up') {
        const pressed = t === 'button_down';
        const idx = typeof index === 'string' ? parseInt(index, 10) : index;
        if (!Number.isInteger(idx) || idx < 0 || idx > 13) return;

        const buttonStr = BUTTON_MAP[idx];
        if (buttonStr) {
            // Fast de-duplicate using array index (no string key creation)
            const prevState = buttonState[idx];
            if (prevState !== pressed) {
                buttonState[idx] = pressed;
                gamepad.pressButton(buttonStr, pressed);
            }
            return;
        }

        // Fast path: Check if it's a D-Pad button (Set lookup is O(1))
        if (DPAD_INDICES.has(idx)) {
            const dpadDir = DPAD_DIRECTIONS[idx];
            // Only update and send if D-Pad state actually changed
            if (dpadState[dpadDir] !== pressed) {
                dpadState[dpadDir] = pressed;
                const dX = dpadState.left ? -1 : dpadState.right ? 1 : 0;
                const dY = dpadState.up ? -1 : dpadState.down ? 1 : 0;
                gamepad.moveDpad(dX, dY);
            }
            return;
        }

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

// Start UDP with optimized buffer sizes
function startUdpServer(port = UDP_PORT) {
    // Set larger UDP buffer for better performance
    udpServer.bind(port, '0.0.0.0', () => {
        try {
            udpServer.setRecvBufferSize(1024 * 256);  // 256KB receive buffer
            udpServer.setSendBufferSize(1024 * 256);  // 256KB send buffer
        } catch (e) {
            // Buffer size setting may fail on some systems, not critical
        }
        logger.info('UDP running on %s', port);
    });
}

// Socket.IO with optimized settings
function initSocketIO(httpServer) {
    ioInstance = new Server(httpServer, {
        // Performance optimizations
        maxHttpBufferSize: 1e6,
        transports: ['websocket', 'polling'],  // Prefer WebSocket for lower latency
        pingInterval: 25000,
        pingTimeout: 20000
    });

    ioInstance.on('connection', (socket) => {
        logger.debug('Web client connected from %s', socket.remoteAddress);

        socket.on('disconnect', () => {
            logger.debug('Web client disconnected');
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
