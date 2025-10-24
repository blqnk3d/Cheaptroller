// index.js
const { loadConfig, getDynamicConfig } = require('./config');
const { startUdpServer, UDP_PORT, stopUdpServer } = require('./udpWebSocket');
const { startWebServer, WEB_PORT } = require('./webserver');
const {
    getLatestInput, getSmoothedAxes, updateOutputAxes,
    mapDirectionToKeysFromAxes, updatePressedDirectionKeys,
    applyMouseMoveByVector
} = require('./inputHandler');
const {
    nowMs, smoothingAlpha, mag01, angleOf, angleDiff, clamp
} = require('./utils');

// ---------- Load persisted settings ----------
loadConfig();

// ---------- Initial State Setup ----------
let lastTime = process.hrtime.bigint();
let tickIntervalMs = Math.round(1000 / getDynamicConfig().TICK_RATE);

// ---------- Main tick loop ----------
function tick() {
    const config = getDynamicConfig();
    const now = process.hrtime.bigint();
    const dtSec = Number(now - lastTime) / 1e9;
    lastTime = now;

    // Recalculate tickInterval in case TICK_RATE was changed by config update
    const newTickIntervalMs = Math.round(1000 / config.TICK_RATE);
    if (newTickIntervalMs !== tickIntervalMs) {
        tickIntervalMs = newTickIntervalMs;
    }

    const alpha = smoothingAlpha(dtSec, config.SMOOTH_TIME);
    const magAlpha = smoothingAlpha(dtSec, config.SMOOTH_TIME * 0.8);
    const latestInput = getLatestInput();
    const smoothed = getSmoothedAxes();
    const lastOutput = require('./inputHandler').getLastOutput(); // Directly access for update

    ['left', 'right'].forEach((side) => {
        let input = latestInput[side];
        // Timeout check for UDP input
        if (nowMs() - input.ts > 250) input = { x: 0, y: 0 };

        const s = smoothed[side];
        // Apply exponential smoothing
        s.x = s.x * (1 - alpha) + input.x * alpha;
        s.y = s.y * (1 - alpha) + input.y * alpha;

        const prev = side === 'left' ? lastOutput.leftAxes : lastOutput.rightAxes;
        const prevMag = mag01(prev.x, prev.y);
        const targetMag = mag01(s.x, s.y);
        const targetAngle = targetMag > 0 ? angleOf(s.x, s.y) : 0;
        const prevAngle = prevMag > 0 ? angleOf(prev.x, prev.y) : 0;

        // Apply turning rate limit
        const maxRad = (config.TURN_RATE_DEG_PER_SEC * dtSec * Math.PI) / 180;
        let newAngle = 0;
        if (prevMag > 0 && targetMag > 0) {
            newAngle = prevAngle + clamp(angleDiff(targetAngle, prevAngle), -maxRad, maxRad);
        } else if (prevMag > 0 && targetMag <= 0) {
            // Decelerating rotation to 0
            newAngle = prevAngle + clamp(angleDiff(0, prevAngle), -maxRad, maxRad);
        } else {
            newAngle = targetAngle;
        }

        // Apply magnitude smoothing
        const newMag = prevMag * (1 - magAlpha) + targetMag * magAlpha;
        const nx = newMag * Math.cos(newAngle);
        const ny = newMag * Math.sin(newAngle);

        updateOutputAxes(side, nx, ny);
    });

    // --- Apply Output to System ---
    const leftAxes = lastOutput.leftAxes;
    const rightAxes = lastOutput.rightAxes;

    // Left Stick: WASD Keys
    const leftMag = mag01(leftAxes.x, leftAxes.y);
    const keys = leftMag < config.DEADZONE ? new Set() : mapDirectionToKeysFromAxes(leftAxes.x, leftAxes.y);
    updatePressedDirectionKeys('left', keys);

    // Right Stick: Mouse Movement
    applyMouseMoveByVector(rightAxes.x, rightAxes.y, dtSec);

    // --- Schedule Next Tick ---
    const next = tickIntervalMs - (Number(process.hrtime.bigint() - now) / 1e6);
    setTimeout(tick, Math.max(0, next));
}

// Start Servers
startUdpServer(UDP_PORT);
const { httpServer } = startWebServer(WEB_PORT);

// Start Main Loop (store timer so we can stop it on shutdown)
let tickTimer = null;
lastTime = process.hrtime.bigint();
tickTimer = setTimeout(function tickWrapper() {
    tick();
    tickTimer = setTimeout(tickWrapper, tickIntervalMs);
}, tickIntervalMs);

// Graceful shutdown
const logger = require('./logger');
function gracefulShutdown(signal) {
    logger.info('SIG received, shutting down: %s', signal);
    try { if (tickTimer) clearTimeout(tickTimer); } catch (e) {}
    try { if (httpServer && typeof httpServer.close === 'function') httpServer.close(); } catch (e) {}
    try { stopUdpServer(); } catch (e) {}
    // allow process to exit
    setTimeout(() => {
        logger.info('Forcing process exit');
        process.exit(0);
    }, 1000);
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));