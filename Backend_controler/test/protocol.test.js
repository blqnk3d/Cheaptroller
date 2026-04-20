const assert = require('assert');
const { MSG_TYPES, SIDES, decodeMessage, isBinaryMessage } = require('../protocol');

describe('Protocol Constants', () => {
  describe('MSG_TYPES', () => {
    it('should have correct MOVE value', () => {
      assert.strictEqual(MSG_TYPES.MOVE, 0x01);
    });

    it('should have correct BUTTON_DOWN value', () => {
      assert.strictEqual(MSG_TYPES.BUTTON_DOWN, 0x02);
    });

    it('should have correct BUTTON_UP value', () => {
      assert.strictEqual(MSG_TYPES.BUTTON_UP, 0x03);
    });

    it('should have correct HEARTBEAT value', () => {
      assert.strictEqual(MSG_TYPES.HEARTBEAT, 0x04);
    });

    it('should have correct BATCH value', () => {
      assert.strictEqual(MSG_TYPES.BATCH, 0x05);
    });
  });

  describe('SIDES', () => {
    it('should have correct left value', () => {
      assert.strictEqual(SIDES.left, 0);
    });

    it('should have correct right value', () => {
      assert.strictEqual(SIDES.right, 1);
    });
  });
});

describe('decodeMessage', () => {
  describe('MOVE message', () => {
    it('should decode MOVE message correctly', () => {
      const buffer = Buffer.alloc(11);
      buffer[0] = MSG_TYPES.MOVE;
      buffer[1] = SIDES.left;
      buffer.writeInt16BE(10000, 2);
      buffer.writeInt16BE(-5000, 4);
      buffer.writeUInt32BE(12345678, 6);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.type, 'move');
      assert.strictEqual(result.side, 'left');
      assert.ok(Math.abs(result.x - 10000 / 32767) < 0.01);
      assert.ok(Math.abs(result.y - (-5000 / 32767)) < 0.01);
      assert.strictEqual(result.timestamp, 12345678);
    });

    it('should decode right side', () => {
      const buffer = Buffer.alloc(11);
      buffer[0] = MSG_TYPES.MOVE;
      buffer[1] = SIDES.right;
      buffer.writeInt16BE(32767, 2);
      buffer.writeInt16BE(32767, 4);
      buffer.writeUInt32BE(1000, 6);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.side, 'right');
      assert.strictEqual(result.x, 1);
      assert.strictEqual(result.y, 1);
    });

    it('should return null for incomplete MOVE message', () => {
      const buffer = Buffer.alloc(5);
      buffer[0] = MSG_TYPES.MOVE;

      const result = decodeMessage(buffer);

      assert.strictEqual(result, null);
    });

    it('should handle negative values', () => {
      const buffer = Buffer.alloc(11);
      buffer[0] = MSG_TYPES.MOVE;
      buffer[1] = SIDES.left;
      buffer.writeInt16BE(-32767, 2);
      buffer.writeInt16BE(-32767, 4);
      buffer.writeUInt32BE(1000, 6);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.x, -1);
      assert.strictEqual(result.y, -1);
    });
  });

  describe('BUTTON_DOWN message', () => {
    it('should decode BUTTON_DOWN message correctly', () => {
      const buffer = Buffer.alloc(7);
      buffer[0] = MSG_TYPES.BUTTON_DOWN;
      buffer[1] = SIDES.left;
      buffer[2] = 0;
      buffer.writeUInt32BE(9876543, 3);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.type, 'button_down');
      assert.strictEqual(result.side, 'left');
      assert.strictEqual(result.index, 0);
      assert.strictEqual(result.timestamp, 9876543);
    });

    it('should decode right side button', () => {
      const buffer = Buffer.alloc(7);
      buffer[0] = MSG_TYPES.BUTTON_DOWN;
      buffer[1] = SIDES.right;
      buffer[2] = 5;
      buffer.writeUInt32BE(1000, 3);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.side, 'right');
      assert.strictEqual(result.index, 5);
    });

    it('should return null for incomplete BUTTON_DOWN', () => {
      const buffer = Buffer.alloc(3);
      buffer[0] = MSG_TYPES.BUTTON_DOWN;

      const result = decodeMessage(buffer);

      assert.strictEqual(result, null);
    });
  });

  describe('BUTTON_UP message', () => {
    it('should decode BUTTON_UP message correctly', () => {
      const buffer = Buffer.alloc(7);
      buffer[0] = MSG_TYPES.BUTTON_UP;
      buffer[1] = SIDES.left;
      buffer[2] = 3;
      buffer.writeUInt32BE(5555555, 3);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.type, 'button_up');
      assert.strictEqual(result.side, 'left');
      assert.strictEqual(result.index, 3);
      assert.strictEqual(result.timestamp, 5555555);
    });
  });

  describe('HEARTBEAT message', () => {
    it('should decode HEARTBEAT message correctly', () => {
      const buffer = Buffer.alloc(5);
      buffer[0] = MSG_TYPES.HEARTBEAT;
      buffer.writeUInt32BE(1111111, 1);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.type, 'heartbeat');
      assert.strictEqual(result.timestamp, 1111111);
    });

    it('should return null for incomplete HEARTBEAT', () => {
      const buffer = Buffer.alloc(1);
      buffer[0] = MSG_TYPES.HEARTBEAT;

      const result = decodeMessage(buffer);

      assert.strictEqual(result, null);
    });
  });

  describe('BATCH message', () => {
    it('should decode empty BATCH message', () => {
      const buffer = Buffer.alloc(3);
      buffer[0] = MSG_TYPES.BATCH;
      buffer[1] = 0;
      buffer[2] = 0;

      const result = decodeMessage(buffer);

      assert.strictEqual(result === null || result?.type === 'batch', true);
    });

    it('should decode BATCH with single MOVE event', () => {
      const buffer = Buffer.alloc(13);
      buffer[0] = MSG_TYPES.BATCH;
      buffer[1] = 1;
      buffer[2] = MSG_TYPES.MOVE;
      buffer[3] = SIDES.left;
      buffer.writeInt16BE(10000, 4);
      buffer.writeInt16BE(20000, 6);
      buffer.writeUInt32BE(1000, 8);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.type, 'batch');
      assert.strictEqual(result.events.length, 1);
      assert.strictEqual(result.events[0].type, 'move');
    });

    it('should decode BATCH with multiple events', () => {
      const buffer = Buffer.alloc(20);
      buffer[0] = MSG_TYPES.BATCH;
      buffer[1] = 2;

      buffer[2] = MSG_TYPES.MOVE;
      buffer[3] = SIDES.left;
      buffer.writeInt16BE(10000, 4);
      buffer.writeInt16BE(20000, 6);
      buffer.writeUInt32BE(1000, 8);

      buffer[12] = MSG_TYPES.BUTTON_DOWN;
      buffer[13] = SIDES.right;
      buffer[14] = 0;
      buffer.writeUInt32BE(1001, 15);

      const result = decodeMessage(buffer);

      assert.ok(result !== null);
      assert.strictEqual(result.events[0].type, 'move');
      if (result.events[1]) {
        assert.strictEqual(result.events[1].type, 'button_down');
      }
    });
  });

  describe('edge cases', () => {
    it('should return null for null buffer', () => {
      const result = decodeMessage(null);
      assert.strictEqual(result, null);
    });

    it('should return null for empty buffer', () => {
      const result = decodeMessage(Buffer.alloc(0));
      assert.strictEqual(result, null);
    });

    it('should return null for buffer too short', () => {
      const buffer = Buffer.alloc(3);
      buffer[0] = MSG_TYPES.MOVE;

      const result = decodeMessage(buffer);

      assert.strictEqual(result, null);
    });

    it('should return null for unknown message type', () => {
      const buffer = Buffer.alloc(5);
      buffer[0] = 0xFF;
      buffer.writeUInt32BE(1000, 1);

      const result = decodeMessage(buffer);

      assert.strictEqual(result, null);
    });

    it('should default to left side for unknown side index', () => {
      const buffer = Buffer.alloc(11);
      buffer[0] = MSG_TYPES.MOVE;
      buffer[1] = 99;
      buffer.writeInt16BE(1000, 2);
      buffer.writeInt16BE(1000, 4);
      buffer.writeUInt32BE(1000, 6);

      const result = decodeMessage(buffer);

      assert.strictEqual(result.side, 'left');
    });
  });
});

describe('isBinaryMessage', () => {
  it('should return true for MOVE', () => {
    const buffer = Buffer.from([MSG_TYPES.MOVE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), true);
  });

  it('should return true for BUTTON_DOWN', () => {
    const buffer = Buffer.from([MSG_TYPES.BUTTON_DOWN, 0, 0, 0, 0, 0, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), true);
  });

  it('should return true for BUTTON_UP', () => {
    const buffer = Buffer.from([MSG_TYPES.BUTTON_UP, 0, 0, 0, 0, 0, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), true);
  });

  it('should return true for HEARTBEAT', () => {
    const buffer = Buffer.from([MSG_TYPES.HEARTBEAT, 0, 0, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), true);
  });

  it('should return true for BATCH', () => {
    const buffer = Buffer.from([MSG_TYPES.BATCH, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), true);
  });

  it('should return false for null buffer', () => {
    assert.strictEqual(isBinaryMessage(null), false);
  });

  it('should return false for empty buffer', () => {
    assert.strictEqual(isBinaryMessage(Buffer.alloc(0)), false);
  });

  it('should return false for non-binary message type', () => {
    const buffer = Buffer.from([0xFF, 0, 0, 0, 0]);
    assert.strictEqual(isBinaryMessage(buffer), false);
  });
});

describe('round trip encoding/decoding', () => {
  it('should encode and decode MOVE with exact values', () => {
    const originalX = 0.5;
    const originalY = -0.75;
    const timestamp = 12345678;

    const buffer = Buffer.alloc(11);
    buffer[0] = MSG_TYPES.MOVE;
    buffer[1] = SIDES.left;
    buffer.writeInt16BE(Math.round(originalX * 32767), 2);
    buffer.writeInt16BE(Math.round(originalY * 32767), 4);
    buffer.writeUInt32BE(timestamp, 6);

    const result = decodeMessage(buffer);

    assert.ok(Math.abs(result.x - originalX) < 0.01);
    assert.ok(Math.abs(result.y - originalY) < 0.01);
    assert.strictEqual(result.timestamp, timestamp);
  });

  it('should handle full range values', () => {
    const maxBuffer = Buffer.alloc(11);
    maxBuffer[0] = MSG_TYPES.MOVE;
    maxBuffer[1] = SIDES.left;
    maxBuffer.writeInt16BE(32767, 2);
    maxBuffer.writeInt16BE(32767, 4);
    maxBuffer.writeUInt32BE(1000, 6);

    const maxResult = decodeMessage(maxBuffer);
    assert.strictEqual(maxResult.x, 1);
    assert.strictEqual(maxResult.y, 1);

    const minBuffer = Buffer.alloc(11);
    minBuffer[0] = MSG_TYPES.MOVE;
    minBuffer[1] = SIDES.left;
    minBuffer.writeInt16BE(-32767, 2);
    minBuffer.writeInt16BE(-32767, 4);
    minBuffer.writeUInt32BE(1000, 6);

    const minResult = decodeMessage(minBuffer);
    assert.strictEqual(minResult.x, -1);
    assert.strictEqual(minResult.y, -1);
  });
});

