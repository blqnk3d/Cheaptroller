// utils.js
const os = require('os');

const nowMs = () => Number(process.hrtime.bigint()) / 1e6;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const magnitude = (x, y) => Math.hypot(x, y);
const normalize = (x, y) => {
    const m = magnitude(x, y);
    return m ? [x / m, y / m] : [0, 0];
};
const mag01 = (x, y) => clamp(magnitude(x, y), 0, 1);
const smoothingAlpha = (dtSec, tauSec) =>
    tauSec <= 0 ? 1.0 : 1 - Math.exp(-dtSec / tauSec);
const angleOf = (x, y) => Math.atan2(y, x);
const angleDiff = (a, b) => {
    let d = a - b;
    while (d <= -Math.PI) d += 2 * Math.PI;
    while (d > Math.PI) d -= 2 * Math.PI;
    return d;
};

function getAllLocalIPs(webPort) {
    const ips = [];
    for (const name of Object.keys(os.networkInterfaces()))
        for (const net of os.networkInterfaces()[name])
            if (net.family === 'IPv4' && !net.internal && !net.address.startsWith('169.254.'))
                ips.push(net.address);
    return ips.length > 0 ? ips : ['127.0.0.1'];
}

module.exports = {
    nowMs,
    clamp,
    magnitude,
    normalize,
    mag01,
    smoothingAlpha,
    angleOf,
    angleDiff,
    getAllLocalIPs
};