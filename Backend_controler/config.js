const fs = require('fs');
const path = require('path');
const os = require('os');

const APP_NAME = 'cheaptroller';

function getConfigPath() {
    const configHome = process.env.XDG_CONFIG_HOME
        ? process.env.XDG_CONFIG_HOME
        : path.join(os.homedir(), '.config');
    return path.join(configHome, APP_NAME);
}

function getConfigFilePath() {
    return path.join(getConfigPath(), 'config.json');
}

const DEFAULTS = {
    webPort: 3000,
    udpPort: 8080,
    stickDeadzone: 0.05,
    clientTimeoutMs: 300000,
    latencyStatsMaxSize: 10,
    debugProtocol: false,
    openBrowser: true,
    bonjourName: 'Cheaptroller PC'
};

let config = { ...DEFAULTS };

function loadConfig() {
    const filePath = getConfigFilePath();
    try {
        const dir = path.dirname(filePath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        if (fs.existsSync(filePath)) {
            const data = fs.readFileSync(filePath, 'utf8');
            const loaded = JSON.parse(data);
            config = { ...DEFAULTS, ...loaded };
            console.log('[Config] Loaded from', filePath);
        } else {
            config = { ...DEFAULTS };
            saveConfig();
            console.log('[Config] Created default config at', filePath);
        }
    } catch (err) {
        console.error('[Config] Error:', err.message);
        config = { ...DEFAULTS };
    }
    return config;
}

function saveConfig() {
    const filePath = getConfigFilePath();
    try {
        const dir = path.dirname(filePath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(filePath, JSON.stringify(config, null, 2), 'utf8');
        console.log('[Config] Saved to', filePath);
        return true;
    } catch (err) {
        console.error('[Config] Save error:', err.message);
        return false;
    }
}

function getConfig() {
    return config;
}

function setConfig(newValues) {
    for (const key of Object.keys(newValues)) {
        if (key in DEFAULTS) {
            const val = newValues[key];
            if (typeof DEFAULTS[key] === 'number') {
                config[key] = Number(val);
            } else {
                config[key] = val;
            }
        }
    }
    return config;
}

function resetConfig() {
    config = { ...DEFAULTS };
    saveConfig();
    return config;
}

module.exports = {
    loadConfig,
    saveConfig,
    getConfig,
    setConfig,
    resetConfig,
    getConfigFilePath,
    DEFAULTS
};