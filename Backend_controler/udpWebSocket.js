// udpWebSocket.js
const dgram = require("dgram");
const { Server } = require("socket.io");
const gamepad = require("./gamepad.node");
const logger = require("./logger");

// UDP
const UDP_PORT = 8080;
let ioInstance = null;
let shuttingDown = false;

// Client management
// Map<string, Object> where key is "ip:port"
const clients = new Map();

const STICK_DEADZONE = 0.05; // Slight increase to 5% to be safe

// High-priority buttons (fastest response needed)
const PRIORITY_BUTTONS = new Set([0, 1, 2, 3]); // A, B, X, Y

// DPAD lookup
const DPAD_INDICES = new Set([10, 11, 12, 13]);
const DPAD_MAP = {
  10: "up",
  11: "down",
  12: "left",
  13: "right",
};

// Button mapping
const BUTTON_MAP = {
  0: "A",
  1: "B",
  2: "X",
  3: "Y",
  4: "LB",
  5: "RB",
  6: "LStick",
  7: "RStick",
  8: "Select",
  9: "Start",
};

// Latency tracking
const latencyStats = {
  count: 0,
  min: Infinity,
  max: -Infinity,
  sum: 0,
  recent: [],
  maxRecentSize: 10,
};

function recordLatency(latencyMs) {
  latencyStats.count++;
  latencyStats.min = Math.min(latencyStats.min, latencyMs);
  latencyStats.max = Math.max(latencyStats.max, latencyMs);
  latencyStats.sum += latencyMs;

  latencyStats.recent.push(latencyMs);
  if (latencyStats.recent.length > latencyStats.maxRecentSize) {
    latencyStats.recent.shift();
  }

  if (latencyStats.count % 100 === 0) {
    // Log every 100th update to reduce noise
    const avg = latencyStats.sum / latencyStats.count;
    logger.debug(
      "⏱️  Latency: %dms (avg: %dms)",
      latencyMs.toFixed(2),
      avg.toFixed(2),
    );
  }
}

// ---------- UDP Server ----------
const udpServer = dgram.createSocket("udp4");

udpServer.on("message", (msg, rinfo) => {
  if (shuttingDown) return;

  let d;
  try {
    // Check if message is MessagePack or JSON
    if (msg[0] === 0x7B) {
      // Starts with '{' -> JSON
      d = JSON.parse(msg);
    } else {
      d = msgpack.decode(msg);
    }
  } catch (e) {
    logger.warn("UDP message decode failed from %s: %s", rinfo.address, e.message);
    return;
  }

  const {
    type: t = d.t,
    side = d.s,
    index = d.i,
    x = d.x,
    y = d.y,
    timestamp: ts = d.ts,
  } = d || {};
  if (!t) return;

  // 1. Identify Client
  const clientKey = `${rinfo.address}:${rinfo.port}`;
  let client = clients.get(clientKey);

  // 2. Register new client if needed
  if (!client) {
    try {
      // Create a new virtual controller for this client
      const controllerId = gamepad.create();

      client = {
        id: controllerId,
        address: rinfo.address,
        port: rinfo.port,
        lastSeen: Date.now(),
        // Isolated state for this controller
        stickState: { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } },
        buttonState: new Array(14).fill(false),
        dpadState: { up: false, down: false, left: false, right: false },
      };

      clients.set(clientKey, client);
      logger.info(
        `🆕 New client connected: ${clientKey} -> Assigned Controller ID: ${controllerId}`,
      );
    } catch (err) {
      logger.error(`❌ Failed to create controller for ${clientKey}:`, err);
      return;
    }
  }

  // Update last seen
  client.lastSeen = Date.now();

  // 3. Handle Latency
  const timestamp = ts || d.timestamp;
  if (timestamp && typeof timestamp === "number" && timestamp > 0) {
    const latencyMs = Date.now() - timestamp;
    if (latencyMs >= 0 && latencyMs < 2000) {
      recordLatency(latencyMs);
    }
  }

  // 4. Process Inputs using Client's ID and State

  // --- STICK MOVEMENT ---
  if (t === "move" && (side === "left" || side === "right")) {
    let xVal = Math.abs(x || 0) < STICK_DEADZONE ? 0 : x || 0;
    let yVal = Math.abs(y || 0) < STICK_DEADZONE ? 0 : y || 0;

    const stickCache = client.stickState[side];
    if (stickCache.x !== xVal || stickCache.y !== yVal) {
      stickCache.x = xVal;
      stickCache.y = yVal;
      // Pass client.id to moveStick
      gamepad.moveStick(
        client.id,
        side,
        Math.round(xVal * 32767),
        Math.round(yVal * 32767),
      );
    }
    return;
  }

  // --- BUTTON PRESSES ---
  if (t === "button_down" || t === "button_up") {
    const pressed = t === "button_down";
    const idx = typeof index === "string" ? parseInt(index, 10) : index;
    if (!Number.isInteger(idx) || idx < 0 || idx > 13) return;

    // Standard Buttons
    const buttonStr = BUTTON_MAP[idx];
    if (buttonStr) {
      if (client.buttonState[idx] !== pressed) {
        client.buttonState[idx] = pressed;
        // Pass client.id to pressButton
        gamepad.pressButton(client.id, buttonStr, pressed);
      }
      return;
    }

    // D-Pad
    if (DPAD_INDICES.has(idx)) {
      const dir = DPAD_MAP[idx]; // 'up', 'down', 'left', 'right'
      if (dir && client.dpadState[dir] !== pressed) {
        client.dpadState[dir] = pressed;

        // Calculate new composite D-Pad axis
        const dX = client.dpadState.left ? -1 : client.dpadState.right ? 1 : 0;
        const dY = client.dpadState.up ? -1 : client.dpadState.down ? 1 : 0;

        // Pass client.id to moveDpad
        gamepad.moveDpad(client.id, dX, dY);
      }
      return;
    }
  }

  if (t === "ip_update" && d.ip) {
    logger.info("Received IP update from %s: %s", rinfo.address, d.ip);
  }
});

// Error handling
udpServer.on("error", (err) => {
  logger.error("UDP server error: %o", err);
  try {
    udpServer.close();
  } catch (e) {}
});

function startUdpServer(port = UDP_PORT) {
  udpServer.bind(port, "0.0.0.0", () => {
    try {
      udpServer.setRecvBufferSize(1024 * 256);
      udpServer.setSendBufferSize(1024 * 256);
    } catch (e) {}
    logger.info("UDP running on %s", port);
  });
}

function initSocketIO(httpServer) {
  ioInstance = new Server(httpServer, {
    maxHttpBufferSize: 1e6,
    transports: ["websocket", "polling"],
    pingInterval: 25000,
    pingTimeout: 20000,
  });

  ioInstance.on("connection", (socket) => {
    logger.debug("Web client connected from %s", socket.remoteAddress);
  });

  return ioInstance;
}

// Close all controllers and clear clients
function closeAllControllers() {
  logger.info(`Closing ${clients.size} active controllers...`);
  clients.forEach((client) => {
    try {
      gamepad.close(client.id);
      logger.debug(`Closed controller ${client.id}`);
    } catch (e) {
      logger.error(`Error closing controller ${client.id}:`, e);
    }
  });
  clients.clear();
}

function stopUdpServer() {
  shuttingDown = true;
  try {
    udpServer.close();
  } catch (e) {}
  if (ioInstance) {
    try {
      ioInstance.close();
    } catch (e) {}
  }
  closeAllControllers();
}

// Initial cleanup on exit
process.on("exit", () => {
  closeAllControllers();
});

module.exports = {
  startUdpServer,
  initSocketIO,
  UDP_PORT,
  stopUdpServer,
  getLatencyStats: () => {
    if (latencyStats.count === 0) return { count: 0, message: "No data" };
    return {
      count: latencyStats.count,
      min: latencyStats.min.toFixed(2),
      max: latencyStats.max.toFixed(2),
      avg: (latencyStats.sum / latencyStats.count).toFixed(2),
      activeClients: clients.size,
    };
  },
};
