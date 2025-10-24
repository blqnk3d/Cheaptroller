// webserver.js
const express = require('express');
const http = require('http');
const { initSocketIO } = require('./udpWebSocket');
const { getStatus } = require('./inputHandler');
const { applyConfig, getDynamicConfig, getAllowFrontendConfig, setAllowFrontendConfig } = require('./config');
const { getAllLocalIPs } = require('./utils');

const WEB_PORT = 3000;

function startWebServer(port = WEB_PORT) {
    const app = express();
    const httpServer = http.createServer(app);

    // Initialize Socket.io
    initSocketIO(httpServer);

    app.use(express.static('public'));
    app.use(express.json());

    // Save config from frontend
    app.post('/api/config', (req, res) => {
        if (getAllowFrontendConfig()) {
            const { tickRateChanged } = applyConfig(req.body);
            res.json({ success: true, config: getDynamicConfig(), tickRateChanged });
        } else {
            res.json({ success: false, reason: 'Frontend config disabled' });
        }
    });

    // Toggle frontend config
    app.post('/api/toggleFrontendConfig', (req, res) => {
        if (setAllowFrontendConfig(req.body.allow)) {
            res.json({ success: true, allowFrontendConfig: getAllowFrontendConfig() });
        } else {
            res.json({ success: false, reason: 'Invalid value' });
        }
    });

    // Return current status and config
    app.get('/api/status', (req, res) => {
        res.json({
            ...getStatus(),
            config: getDynamicConfig(),
            allowFrontendConfig: getAllowFrontendConfig()
        });
    });

    // API endpoint for local IPs
    app.get('/api/myip', (req, res) => {
        res.json({ ips: getAllLocalIPs(), port: WEB_PORT });
    });

    httpServer.listen(port, () => {
        const logger = require('./logger');
        logger.info('🌐 Web server running on http://localhost:%s | IPs: %s', port, getAllLocalIPs().join(' | '));
    });

    return { app, httpServer };
}

module.exports = {
    startWebServer,
    WEB_PORT
};