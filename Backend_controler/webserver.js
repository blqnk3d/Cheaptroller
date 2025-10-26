const express = require('express');
const http = require('http');
const path = require('path');
const { getAllLocalIPs } = require('./utils');
const { initSocketIO } = require('./udpWebSocket');

const WEB_PORT = 3000;

function startWebServer(port = WEB_PORT) {
    const app = express();
    const httpServer = http.createServer(app);

    // Initialize Socket.io if needed
    initSocketIO(httpServer);

    // API endpoint to get local IPs
    app.get('/api/myip', (req, res) => {
        res.json({ ips: getAllLocalIPs(), port: WEB_PORT });
    });

    // Serve static files from public/
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

module.exports = { startWebServer, WEB_PORT };
