// utils.js
const os = require('os');


function getAllLocalIPs(webPort) {
    const ips = [];
    for (const name of Object.keys(os.networkInterfaces()))
        for (const net of os.networkInterfaces()[name])
            if (net.family === 'IPv4' && !net.internal && !net.address.startsWith('169.254.'))
                ips.push(net.address);
    return ips.length > 0 ? ips : ['127.0.0.1'];
}

module.exports = {
    getAllLocalIPs
};