// config.js
const fs = require('fs');
const path = require('path');

const SETTINGS_FILE = path.join(__dirname, 'controller_config.json');

let dynamicConfig = {
  "MAX_SPEED": 54,
  "DEADZONE": 0,
  "DEADZONE_EXIT": 0.045,
  "SMOOTH_TIME": 0,
  "TICK_RATE": 144,
  "TURN_RATE_DEG_PER_SEC": 779,
  "SENSITIVITY_CURVE": 0.1,
  "allowFrontendConfig": true
}
;


let ALLOW_FRONTEND_CONFIG = true;

function loadConfig() {
    if (fs.existsSync(SETTINGS_FILE)) {
        try {
            const data = JSON.parse(fs.readFileSync(SETTINGS_FILE));
            Object.assign(dynamicConfig, data);
            if (typeof data.allowFrontendConfig === 'boolean') {
                ALLOW_FRONTEND_CONFIG = data.allowFrontendConfig;
            }
            console.log('⚡ Loaded persisted config:', dynamicConfig, 'Frontend config:', ALLOW_FRONTEND_CONFIG);
        } catch (e) {
            console.error('❌ Failed to load persisted config:', e);
        }
    }
}

function saveConfig() {
    try {
        const configToSave = {
            ...dynamicConfig,
            allowFrontendConfig: ALLOW_FRONTEND_CONFIG
        };
        fs.writeFileSync(
            SETTINGS_FILE,
            JSON.stringify(configToSave, null, 2)
        );
    } catch (e) {
        console.error('❌ Failed to save config:', e);
    }
}

function applyConfig(updates, persist = true) {
    let tickRateChanged = false;
    if (typeof updates !== 'object') return;
    for (const [k, v] of Object.entries(updates)) {
        if (dynamicConfig.hasOwnProperty(k) && typeof v === 'number') {
            if (k === 'TICK_RATE' && dynamicConfig.TICK_RATE !== v) {
                tickRateChanged = true;
            }
            dynamicConfig[k] = v;
        }
    }
    if (persist) saveConfig();
    console.log('🔧 Config applied:', dynamicConfig);
    return { tickRateChanged };
}

function getDynamicConfig() {
    return dynamicConfig;
}

function setAllowFrontendConfig(allow) {
    if (typeof allow === 'boolean') {
        ALLOW_FRONTEND_CONFIG = allow;
        saveConfig();
        console.log('⚡ ALLOW_FRONTEND_CONFIG =', ALLOW_FRONTEND_CONFIG);
        return true;
    }
    return false;
}

function getAllowFrontendConfig() {
    return ALLOW_FRONTEND_CONFIG;
}

module.exports = {
    loadConfig,
    saveConfig,
    applyConfig,
    getDynamicConfig,
    setAllowFrontendConfig,
    getAllowFrontendConfig,
};