const MSG_TYPES = {
  MOVE: 0x01,
  BUTTON_DOWN: 0x02,
  BUTTON_UP: 0x03,
  HEARTBEAT: 0x04,
  BATCH: 0x05,
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
      case MSG_TYPES.BATCH: {
        if (view.length < 3) return null;
        const count = view[1];
        const events = [];
        let offset = 2;

        for (let i = 0; i < count && offset < view.length; i++) {
          const msgType = view[offset];
          let event = null;

          switch (msgType) {
            case MSG_TYPES.MOVE: {
              if (offset + 10 < view.length) {
                const side = SIDE_NAMES[view[offset + 1]] || "left";
                const x = view.readInt16BE(offset + 2) / 32767;
                const y = view.readInt16BE(offset + 4) / 32767;
                const timestamp = view.readUInt32BE(offset + 6);
                event = { type: "move", side, x, y, timestamp };
                offset += 11;
              }
              break;
            }
            case MSG_TYPES.BUTTON_DOWN: {
              if (offset + 6 < view.length) {
                const side = SIDE_NAMES[view[offset + 1]] || "left";
                const index = view[offset + 2];
                const timestamp = view.readUInt32BE(offset + 3);
                event = { type: "button_down", side, index, timestamp };
                offset += 7;
              }
              break;
            }
            case MSG_TYPES.BUTTON_UP: {
              if (offset + 6 < view.length) {
                const side = SIDE_NAMES[view[offset + 1]] || "left";
                const index = view[offset + 2];
                const timestamp = view.readUInt32BE(offset + 3);
                event = { type: "button_up", side, index, timestamp };
                offset += 7;
              }
              break;
            }
            default:
              offset = view.length;
          }

          if (event) events.push(event);
        }

        return { type: "batch", events };
      }
      default:
        return null;
    }
  } catch (e) {
    return null;
  }
}

module.exports = {
  MSG_TYPES,
  SIDES,
  decodeMessage,
};
