const express = require('express');
const http = require('http');
const path = require('path');
const { getAllLocalIPs } = require('./utils');
const { initSocketIO, getLatencyStats } = require('./udpWebSocket');

const WEB_PORT = 3000;

let httpServer = null;
let ioInstance = null;
let shuttingDown = false;

function startWebServer(port = WEB_PORT) {
    const app = express();
    httpServer = http.createServer(app);

    // Initialize Socket.IO
    ioInstance = initSocketIO(httpServer);

    // API endpoint to get local IPs
    app.get('/api/myip', (req, res) => {
        res.json({ ips: getAllLocalIPs(), port: WEB_PORT });
    });

    // API endpoint to get latency statistics
    app.get('/api/latency', (req, res) => {
        res.json(getLatencyStats());
    });

    // Shutdown endpoint
    app.post('/api/shutdown', (req, res) => {
        res.json({ status: 'shutting down' });
        shutdown('web endpoint');
    });

    // Serve static files
    const publicPath = path.join(__dirname, 'public');
    app.use(express.static(publicPath));

    // SPA fallback
    app.get('/', (req, res) => {
        res.sendFile(path.join(publicPath, 'index.html'));
    });

    httpServer.listen(port, () => {
        console.log(`🌐 Web GUI running on http://localhost:${port} | IPs: ${getAllLocalIPs().join(' | ')}`);
    });

    return { app, httpServer };
}

function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log('🛑 Web server shutting down', signal || '');

    try { httpServer.close(); } catch (e) {}
    if (ioInstance && typeof ioInstance.close === 'function') {
        try { ioInstance.close(); } catch (e) { console.error('Error closing Socket.IO:', e); }
    }

    setTimeout(() => {
        console.log('🛑 Forcing process exit');
        try { process.exit(0); } catch (e) {}
    }, 1000);
}

module.exports = { startWebServer, WEB_PORT, shutdown };
