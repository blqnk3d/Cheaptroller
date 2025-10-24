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
            const logger = require('./logger');
            logger.info('⚡ Loaded persisted config: %o Frontend config: %s', dynamicConfig, ALLOW_FRONTEND_CONFIG);
        } catch (e) {
            const logger = require('./logger');
            logger.error('❌ Failed to load persisted config: %o', e);
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
        const logger = require('./logger');
        logger.error('❌ Failed to save config: %o', e);
    }
}

function applyConfig(updates, persist = true) {
    let tickRateChanged = false;
    if (typeof updates !== 'object') return;
    for (const [k, v] of Object.entries(updates)) {
        if (!dynamicConfig.hasOwnProperty(k)) continue;
        // Numeric updates
        if (typeof dynamicConfig[k] === 'number' && typeof v === 'number') {
            if (k === 'TICK_RATE') {
                // Clamp tick rate to reasonable bounds to avoid runaway CPU usage
                const clamped = Math.max(10, Math.min(240, Math.round(v)));
                if (dynamicConfig.TICK_RATE !== clamped) tickRateChanged = true;
                dynamicConfig.TICK_RATE = clamped;
            } else {
                dynamicConfig[k] = v;
            }
        }
    }
    if (persist) saveConfig();
    const logger = require('./logger');
    logger.info('🔧 Config applied: %o', dynamicConfig);
    return { tickRateChanged };
}

function getDynamicConfig() {
    return dynamicConfig;
}

function setAllowFrontendConfig(allow) {
    if (typeof allow === 'boolean') {
        ALLOW_FRONTEND_CONFIG = allow;
        saveConfig();
        const logger = require('./logger');
        logger.info('⚡ ALLOW_FRONTEND_CONFIG = %s', ALLOW_FRONTEND_CONFIG);
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