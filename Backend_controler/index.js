// index.js
const { startUdpServer, UDP_PORT, stopUdpServer } = require('./udpWebSocket');
const { startWebServer, WEB_PORT } = require('./webserver');

const {
    nowMs, smoothingAlpha, mag01, angleOf, angleDiff, clamp
} = require('./utils');


// Start Servers
startUdpServer(UDP_PORT);
const { httpServer } = startWebServer(WEB_PORT);


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