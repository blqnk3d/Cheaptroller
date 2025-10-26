const { startUdpServer, UDP_PORT, stopUdpServer } = require('./udpWebSocket');
const { startWebServer, WEB_PORT } = require('./webserver');
const logger = require('./logger');
const { exec } = require('child_process');

// Start Servers
startUdpServer(UDP_PORT);
const { httpServer } = startWebServer(WEB_PORT);

// Funktion zum Browser-Öffnen
function openBrowser(url) {
  const platform = process.platform;

  try {
    if (platform === 'win32') {
      exec(`start ${url}`);
    } else if (platform === 'darwin') {
      exec(`open ${url}`);
    } else if (platform === 'linux') {
      exec(`xdg-open ${url}`);
    }
    logger.info(`Opening browser at ${url}`);
  } catch (err) {
    logger.error('Failed to open browser:', err);
  }
}

// Browser nach kurzem Delay öffnen
setTimeout(() => {
  const url = `http://localhost:${WEB_PORT}`;
  openBrowser(url);
}, 500);

// Graceful Shutdown
function gracefulShutdown(signal) {
  logger.info('SIG received, shutting down: %s', signal);
  try { if (tickTimer) clearTimeout(tickTimer); } catch (e) {}
  try { if (httpServer && typeof httpServer.close === 'function') httpServer.close(); } catch (e) {}
  try { stopUdpServer(); } catch (e) {}
  setTimeout(() => {
    logger.info('Forcing process exit');
    process.exit(0);
  }, 1000);
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
