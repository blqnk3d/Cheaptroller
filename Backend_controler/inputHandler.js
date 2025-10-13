// inputHandler.js
const robot = require('robotjs');
const { nowMs, clamp, mag01, normalize } = require('./utils');
const { getDynamicConfig } = require('./config');

let screenSize, mousePos;
try {
    screenSize = robot.getScreenSize();
    mousePos = robot.getMousePos();
} catch (e) {
    console.error('❌ RobotJS failed:', e);
    // Fallback in case robotjs fails (e.g., missing X server)
    screenSize = { width: 1920, height: 1080 };
    mousePos = { x: 960, y: 540 };
}

// State
let latestInput = { left: { x: 0, y: 0, ts: 0 }, right: { x: 0, y: 0, ts: 0 } };
let smoothed = { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } };
let lastOutput = { leftAxes: { x: 0, y: 0 }, rightAxes: { x: 0, y: 0 }, mousePosSub: { x: 0, y: 0 } };
let pressedButtons = { left: new Set(), right: new Set() };
let pressedDirectionKeys = new Set();
let lastKeyToggleTime = 0;

function updateLatestInput(side, x, y) {
    latestInput[side] = { x, y, ts: nowMs() };
}

function handleButton(side, idx, down) {
    const config = getDynamicConfig();
    if (side === 'left') {
        if (idx === 0) robot.mouseToggle(down ? 'down' : 'up', 'left');
        else if (idx === 1) robot.mouseToggle(down ? 'down' : 'up', 'right');
        else if (idx === 2) robot.mouseToggle(down ? 'down' : 'up', 'middle');
        else if (idx === 3) robot.keyToggle('escape', down ? 'down' : 'up'); // Example: Back/Select
        else if (idx === 4) robot.keyToggle('shift', down ? 'down' : 'up'); // Example: LB
        else if (idx === 5) robot.keyToggle('control', down ? 'down' : 'up'); // Example: RB
        return;
    }
    const key = { right: { 0: 'enter', 1: 'tab', 2: ' ' } }[side]?.[idx];
    if (key) robot.keyToggle(key, down ? 'down' : 'up');

    if (down) pressedButtons[side].add(idx);
    else pressedButtons[side].delete(idx);
}

function mapDirectionToKeysFromAxes(ax, ay) {
    const config = getDynamicConfig();
    const keys = new Set();
    if (ay < -config.DEADZONE) keys.add('w');
    else if (ay > config.DEADZONE) keys.add('s');
    if (ax < -config.DEADZONE) keys.add('a');
    else if (ax > config.DEADZONE) keys.add('d');
    return keys;
}

function updatePressedDirectionKeys(side, newKeys) {
    const now = nowMs();
    // Release keys not in newKeys
    for (const key of Array.from(pressedDirectionKeys))
        if (!newKeys.has(key) && now - lastKeyToggleTime > 30) {
            robot.keyToggle(key, 'up');
            pressedDirectionKeys.delete(key);
            lastKeyToggleTime = now;
        }
    // Press keys in newKeys but not in pressedDirectionKeys
    for (const key of newKeys)
        if (!pressedDirectionKeys.has(key) && now - lastKeyToggleTime > 30) {
            robot.keyToggle(key, 'down');
            pressedDirectionKeys.add(key);
            lastKeyToggleTime = now;
        }
}

function applyMouseMoveByVector(nx, ny, dtSec) {
    const config = getDynamicConfig();

    // --- Apply per-axis deadzone ---
    const dx = Math.abs(nx) < config.DEADZONE ? 0 : nx;
    const dy = Math.abs(ny) < config.DEADZONE ? 0 : ny;

    if (dx === 0 && dy === 0) return; // Nothing to move

    // --- Linear movement with optional exponential acceleration ---
    // accelerationFactor = 1 means fully linear (default)
    const accelFactor = config.ACCELERATION_FACTOR || 1;

    const speedX = Math.sign(dx) * Math.pow(Math.abs(dx), accelFactor) * config.MAX_SPEED;
    const speedY = Math.sign(dy) * Math.pow(Math.abs(dy), accelFactor) * config.MAX_SPEED;

    // --- Accumulate fractional movement for smooth sub-pixel handling ---
    lastOutput.mousePosSub.x += speedX * dtSec;
    lastOutput.mousePosSub.y += speedY * dtSec;

    const moveX = Math.trunc(lastOutput.mousePosSub.x);
    const moveY = Math.trunc(lastOutput.mousePosSub.y);

    if (moveX !== 0 || moveY !== 0) {
        // --- Clamp to screen boundaries ---
        mousePos.x = clamp(mousePos.x + moveX, 0, screenSize.width - 1);
        mousePos.y = clamp(mousePos.y + moveY, 0, screenSize.height - 1);

        // --- Move the mouse instantly ---
        robot.moveMouse(mousePos.x, mousePos.y);

        // --- Keep fractional remainder for next tick ---
        lastOutput.mousePosSub.x -= moveX;
        lastOutput.mousePosSub.y -= moveY;
    }
}



function getStatus() {
    return {
        leftAxes: lastOutput.leftAxes,
        rightAxes: lastOutput.rightAxes,
        mousePos,
        pressedKeys: Array.from(pressedDirectionKeys),
        pressedButtons,
    };
}

function getLatestInput() {
    return latestInput;
}

function getSmoothedAxes() {
    return smoothed;
}

function getLastOutput() {
    return lastOutput;
}

function updateOutputAxes(side, x, y) {
    if (side === 'left') lastOutput.leftAxes = { x, y };
    else if (side === 'right') lastOutput.rightAxes = { x, y };
}

module.exports = {
    updateLatestInput,
    handleButton,
    mapDirectionToKeysFromAxes,
    updatePressedDirectionKeys,
    applyMouseMoveByVector,
    getStatus,
    getLatestInput,
    getSmoothedAxes,
    getLastOutput,
    updateOutputAxes
};