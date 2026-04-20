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

const ConfigSchema = {
    webPort: { min: 1, max: 65535, type: 'number' },
    udpPort: { min: 1, max: 65535, type: 'number' },
    stickDeadzone: { min: 0, max: 1, type: 'number' },
    clientTimeoutMs: { min: 1000, max: 3600000, type: 'number' },
    latencyStatsMaxSize: { min: 1, max: 1000, type: 'number' },
    debugProtocol: { type: 'boolean' },
    openBrowser: { type: 'boolean' },
    bonjourName: { type: 'string', minLen: 1, maxLen: 63 }
};

let config = { ...DEFAULTS };
let loaded = false;

function validateConfigValue(key, value) {
    const schema = ConfigSchema[key];
    if (!schema) return false;

    if (schema.type === 'number') {
        const num = Number(value);
        if (isNaN(num)) return false;
        if (schema.min !== undefined && num < schema.min) return false;
        if (schema.max !== undefined && num > schema.max) return false;
        return num;
    }

    if (schema.type === 'boolean') {
        return value === true || value === false || value === 'true' || value === 'false'
            ? (typeof value === 'string' ? value === 'true' : value)
            : false;
    }

    if (schema.type === 'string') {
        const str = String(value);
        if (schema.minLen !== undefined && str.length < schema.minLen) return false;
        if (schema.maxLen !== undefined && str.length > schema.maxLen) return false;
        return str;
    }

    return false;
}

function loadConfig() {
    if (loaded) return config;

    const filePath = getConfigFilePath();
    try {
        const dir = path.dirname(filePath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        if (fs.existsSync(filePath)) {
            const data = fs.readFileSync(filePath, 'utf8');
            const parsed = JSON.parse(data);
            config = { ...DEFAULTS };
            for (const key of Object.keys(parsed)) {
                const validated = validateConfigValue(key, parsed[key]);
                if (validated !== false) {
                    config[key] = validated;
                }
            }
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

    loaded = true;
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
            const validated = validateConfigValue(key, newValues[key]);
            if (validated !== false) {
                config[key] = validated;
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