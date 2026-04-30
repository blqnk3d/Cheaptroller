// udpWebSocket.js
const dgram = require("dgram");
const { Server } = require("socket.io");
const gamepad = require("./gamepad.node");
const logger = require("./logger");
const { decodeMessage, isBinaryMessage } = require("./protocol");
const config = require("./config");

const cfg = config.getConfig();

const UDP_PORT = cfg.udpPort;
let ioInstance = null;
let shuttingDown = false;

const DEBUG_PROTOCOL = cfg.debugProtocol;

function debugProtocol(...args) {
  if (DEBUG_PROTOCOL) {
    console.log("[PROTOCOL]", ...args);
  }
}

// Client management
// Map<string, Object> where key is "ip:port"
const clients = new Map();

const STICK_DEADZONE = cfg.stickDeadzone;

const CLIENT_TIMEOUT_MS = cfg.clientTimeoutMs;

// DPAD lookup
const DPAD_INDICES = new Set([10, 11, 12, 13]);
const DPAD_MAP = {
  10: "Up",
  11: "Down",
  12: "Left",
  13: "Right",
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
  maxRecentSize: cfg.latencyStatsMaxSize,
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

  debugProtocol(
    "Received",
    msg.length,
    "bytes from",
    rinfo.address + ":" + rinfo.port,
  );

  let d;
  if (isBinaryMessage(msg)) {
    d = decodeMessage(msg);
    debugProtocol("Binary decoded:", JSON.stringify(d));
  } else {
    try {
      d = JSON.parse(msg);
      debugProtocol("JSON decoded:", JSON.stringify(d));
    } catch (_) {
      logger.warn("UDP message not valid from %s", rinfo.address);
      return;
    }
  }

  if (!d) {
    debugProtocol("Decode failed!");
    return;
  }

  const { type: t, side, index, x, y, timestamp, events } = d;

  const clientKey = `${rinfo.address}:${rinfo.port}`;
  let client = clients.get(clientKey);

  if (!client) {
    try {
      const controllerId = gamepad.create();

      client = {
        id: controllerId,
        address: rinfo.address,
        lastSeen: Date.now(),
        stickState: { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } },
        buttonState: new Array(14).fill(false),
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

  client.lastSeen = Date.now();

  if (timestamp && typeof timestamp === "number" && timestamp > 0) {
    const latencyMs = Date.now() - timestamp;
    if (latencyMs >= 0 && latencyMs < 2000) {
      recordLatency(latencyMs);
    }
  }

  if (t === "batch" && events) {
    debugProtocol("Processing BATCH with", events.length, "events");

    const batchSticks = {
      left: { x: null, y: null },
      right: { x: null, y: null },
    };
    const batchDpad = { x: 0, y: 0, changed: false };

    // 1. Process all button events immediately (High Priority)
    // and collect the LATEST stick/dpad state from the batch
    for (const event of events) {
      if (event.type === "button_down" || event.type === "button_up") {
        const idx =
          typeof event.index === "string"
            ? parseInt(event.index, 10)
            : event.index;
        
        processEvent(client, event); // Process everything immediately for max speed

        if (DPAD_INDICES.has(idx)) {
          batchDpad.changed = true;
          const pressed = event.type === "button_down";
          if (idx === 10) batchDpad.y = pressed ? -1 : (client.buttonState[11] ? 1 : 0);
          else if (idx === 11) batchDpad.y = pressed ? 1 : (client.buttonState[10] ? -1 : 0);
          else if (idx === 12) batchDpad.x = pressed ? -1 : (client.buttonState[13] ? 1 : 0);
          else if (idx === 13) batchDpad.x = pressed ? 1 : (client.buttonState[12] ? -1 : 0);
        }
      } else if (event.type === "move") {
        if (event.side === "left" || event.side === "right") {
          if (event.x !== undefined) batchSticks[event.side].x = event.x;
          if (event.y !== undefined) batchSticks[event.side].y = event.y;
        }
      }
    }

    // 2. Apply consolidated Stick states (Low Priority)
    for (const side of ["left", "right"]) {
      const s = batchSticks[side];
      if (s.x !== null || s.y !== null) {
        processEvent(client, {
          type: "move",
          side,
          x: s.x ?? client.stickState[side].x,
          y: s.y ?? client.stickState[side].y,
        });
      }
    }
    return;
  }

  debugProtocol("Processing single event:", t, side, index, x, y);
  processEvent(client, { type: t, side, index, x, y, timestamp });

  if (t === "ip_update" && d.ip) {
    logger.info("Received IP update from %s: %s", rinfo.address, d.ip);
  }
});

function processEvent(client, d) {
  const { type: t, side, index, x, y } = d;

  if (t === "move" && (side === "left" || side === "right")) {
    const xVal = Math.abs(x || 0) < STICK_DEADZONE ? 0 : x || 0;
    const yVal = Math.abs(y || 0) < STICK_DEADZONE ? 0 : y || 0;

    const stickCache = client.stickState[side];
    if (stickCache.x !== xVal || stickCache.y !== yVal) {
      stickCache.x = xVal;
      stickCache.y = yVal;
      gamepad.moveStick(
        client.id,
        side,
        Math.round(xVal * 32767),
        Math.round(yVal * 32767),
      );
    }
    return;
  }

  if (t === "button_down" || t === "button_up") {
    const pressed = t === "button_down";
    const idx = typeof index === "string" ? parseInt(index, 10) : index;
    if (!Number.isInteger(idx) || idx < 0 || idx > 13) return;

    const buttonStr = BUTTON_MAP[idx];
    if (buttonStr) {
      if (client.buttonState[idx] !== pressed) {
        client.buttonState[idx] = pressed;
        gamepad.pressButton(client.id, buttonStr, pressed);
      }
      return;
    }

    if (DPAD_INDICES.has(idx)) {
      if (client.buttonState[idx] !== pressed) {
        client.buttonState[idx] = pressed;
        // Calculate combined D-pad state
        const dx = (client.buttonState[12] ? -1 : 0) + (client.buttonState[13] ? 1 : 0);
        const dy = (client.buttonState[10] ? -1 : 0) + (client.buttonState[11] ? 1 : 0);
        gamepad.moveDpad(client.id, dx, dy);
      }
      return;
    }
  }
}

// Error handling
udpServer.on("error", (err) => {
  if (err.code === 'EADDRINUSE') {
    logger.error(`UDP port ${UDP_PORT} is already in use. Please choose a different port.`);
  } else if (err.code === 'EACCES') {
    logger.error(`Permission denied to use UDP port ${UDP_PORT}. Try a port above 1024.`);
  } else {
    logger.error("UDP server error: %o", err);
  }
  try {
    udpServer.close();
  } catch (_) {}
  process.exit(1);
});

function startUdpServer(port = UDP_PORT) {
  udpServer.bind(port, "0.0.0.0", () => {
    try {
      udpServer.setRecvBufferSize(1024 * 256);
      udpServer.setSendBufferSize(1024 * 256);
    } catch (_) {}
    logger.info("UDP running on %s", port);
  });

  setInterval(() => {
    const now = Date.now();
    for (const [key, client] of clients) {
      if (now - client.lastSeen > CLIENT_TIMEOUT_MS) {
        try {
          gamepad.close(client.id);
          logger.info(
            `🗑️  Closed stale controller ${client.id} for ${key} (no data for ${CLIENT_TIMEOUT_MS}ms)`,
          );
        } catch (e) {
          logger.error(`Error closing controller ${client.id}:`, e);
        }
        clients.delete(key);
      }
    }
  }, 2000);
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
  } catch (_) {}
  if (ioInstance) {
    try {
      ioInstance.close();
    } catch (_) {}
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
