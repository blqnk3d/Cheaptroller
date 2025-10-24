const util = require('util');

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
let currentLevel = process.env.LOG_LEVEL ? process.env.LOG_LEVEL.toLowerCase() : 'info';
if (!LEVELS.hasOwnProperty(currentLevel)) currentLevel = 'info';

const colors = {
  error: '\x1b[31m', // red
  warn: '\x1b[33m', // yellow
  info: '\x1b[32m', // green
  debug: '\x1b[36m', // cyan
  reset: '\x1b[0m'
};

function shouldLog(level) {
  return LEVELS[level] <= LEVELS[currentLevel];
}

function format(level, args) {
  const ts = new Date().toISOString();
  const msg = util.format.apply(null, args);
  return `${colors[level] || ''}[${ts}] [${level.toUpperCase()}] ${msg}${colors.reset}`;
}

function error(...args) {
  if (!shouldLog('error')) return;
  console.error(format('error', args));
}

function warn(...args) {
  if (!shouldLog('warn')) return;
  console.warn(format('warn', args));
}

function info(...args) {
  if (!shouldLog('info')) return;
  console.log(format('info', args));
}

function debug(...args) {
  if (!shouldLog('debug')) return;
  console.log(format('debug', args));
}

function setLevel(lvl) {
  const lc = String(lvl || '').toLowerCase();
  if (LEVELS.hasOwnProperty(lc)) currentLevel = lc;
}

module.exports = { error, warn, info, debug, setLevel };
