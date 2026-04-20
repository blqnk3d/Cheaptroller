const express = require('express');
const http = require('http');
const path = require('path');
const { getAllLocalIPs } = require('./utils');
const { initSocketIO, getLatencyStats } = require('./udpWebSocket');
const config = require('./config');

const WEB_PORT = config.getConfig().webPort;

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

    // Health check endpoint
    app.get('/api/health', (req, res) => {
        res.json({
            status: 'ok',
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            timestamp: Date.now()
        });
    });

    // Shutdown endpoint
    app.post('/api/shutdown', (req, res) => {
        res.json({ status: 'shutting down' });
        shutdown('web endpoint');
    });

    // GET config endpoint
    app.get('/api/config', (req, res) => {
        const cfg = config.getConfig();
        cfg.configPath = config.getConfigFilePath();
        res.json(cfg);
    });

    // SET config endpoint
    app.post('/api/config', express.json(), (req, res) => {
        const newConfig = config.setConfig(req.body);
        config.saveConfig();
        res.json(newConfig);
    });

    // Reset config endpoint
    app.post('/api/config/reset', (req, res) => {
        config.resetConfig();
        res.json(config.getConfig());
    });

    // Serve static files
    const publicPath = path.join(__dirname, 'public');
    app.use(express.static(publicPath));

    // SPA fallback
    app.get('/', (req, res) => {
        res.sendFile(path.join(publicPath, 'index.html'));
    });

    httpServer.on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
            console.error(`❌ Port ${port} is already in use. Please choose a different port.`);
        } else if (err.code === 'EACCES') {
            console.error(`❌ Permission denied to use port ${port}. Try a port above 1024.`);
        } else {
            console.error(`❌ Server error: ${err.message}`);
        }
        process.exit(1);
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
