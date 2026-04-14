const MSG_TYPES = {
  MOVE: 0x01,
  BUTTON_DOWN: 0x02,
  BUTTON_UP: 0x03,
  HEARTBEAT: 0x04,
};

const SIDES = {
  left: 0,
  right: 1,
};

const SIDE_NAMES = ["left", "right"];

function decodeMessage(buffer) {
  if (!buffer || buffer.length < 5) return null;

  try {
    const view = buffer instanceof Buffer ? buffer : Buffer.from(buffer);
    const type = view[0];

    switch (type) {
      case MSG_TYPES.MOVE: {
        if (view.length < 11) return null;
        const side = SIDE_NAMES[view[1]] || "left";
        const x = view.readInt16BE(2) / 32767;
        const y = view.readInt16BE(4) / 32767;
        const timestamp = view.readUInt32BE(6);
        return { type: "move", side, x, y, timestamp };
      }
      case MSG_TYPES.BUTTON_DOWN: {
        if (view.length < 7) return null;
        const side = SIDE_NAMES[view[1]] || "left";
        const index = view[2];
        const timestamp = view.readUInt32BE(3);
        return { type: "button_down", side, index, timestamp };
      }
      case MSG_TYPES.BUTTON_UP: {
        if (view.length < 7) return null;
        const side = SIDE_NAMES[view[1]] || "left";
        const index = view[2];
        const timestamp = view.readUInt32BE(3);
        return { type: "button_up", side, index, timestamp };
      }
      case MSG_TYPES.HEARTBEAT: {
        if (view.length < 5) return null;
        const timestamp = view.readUInt32BE(1);
        return { type: "heartbeat", timestamp };
      }
      default:
        return null;
    }
  } catch (e) {
    return null;
  }
}

function isBinaryMessage(buffer) {
  if (!buffer || buffer.length === 0) return false;
  const firstByte = buffer instanceof Buffer ? buffer[0] : buffer[0];
  return (
    firstByte === MSG_TYPES.MOVE ||
    firstByte === MSG_TYPES.BUTTON_DOWN ||
    firstByte === MSG_TYPES.BUTTON_UP ||
    firstByte === MSG_TYPES.HEARTBEAT
  );
}

module.exports = {
  MSG_TYPES,
  SIDES,
  decodeMessage,
  isBinaryMessage,
};
