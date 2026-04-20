const assert = require('assert');

describe('UDP WebSocket Logic (Latency Tracking)', () => {
  let latencyStats;
  let recordLatency;
  let getLatencyStats;

  beforeEach(() => {
    latencyStats = {
      count: 0,
      min: Infinity,
      max: -Infinity,
      sum: 0,
      recent: [],
      maxRecentSize: 10,
    };

    recordLatency = (latencyMs) => {
      latencyStats.count++;
      latencyStats.min = Math.min(latencyStats.min, latencyMs);
      latencyStats.max = Math.max(latencyStats.max, latencyMs);
      latencyStats.sum += latencyMs;

      latencyStats.recent.push(latencyMs);
      if (latencyStats.recent.length > latencyStats.maxRecentSize) {
        latencyStats.recent.shift();
      }
    };

    getLatencyStats = () => {
      if (latencyStats.count === 0) return { count: 0, message: "No data" };
      return {
        count: latencyStats.count,
        min: latencyStats.min.toFixed(2),
        max: latencyStats.max.toFixed(2),
        avg: (latencyStats.sum / latencyStats.count).toFixed(2),
      };
    };
  });

  describe('recordLatency', () => {
    it('sollte Latenz korrekt aufzeichnen', () => {
      recordLatency(50);
      assert.strictEqual(latencyStats.count, 1);
      assert.strictEqual(latencyStats.min, 50);
      assert.strictEqual(latencyStats.max, 50);
      assert.strictEqual(latencyStats.sum, 50);
    });

    it('sollte min und max korrekt aktualisieren', () => {
      recordLatency(50);
      recordLatency(100);
      recordLatency(25);
      assert.strictEqual(latencyStats.min, 25);
      assert.strictEqual(latencyStats.max, 100);
      assert.strictEqual(latencyStats.sum, 175);
    });

    it('sollte recent Liste auf max 10 begrenzen', () => {
      for (let i = 0; i < 15; i++) {
        recordLatency(i);
      }
      assert.strictEqual(latencyStats.recent.length, 10);
      assert.strictEqual(latencyStats.recent[0], 5);
    });
  });

  describe('getLatencyStats', () => {
    it('sollte "No data" zurückgeben wenn keine Daten', () => {
      const stats = getLatencyStats();
      assert.strictEqual(stats.message, "No data");
    });

    it('sollte korrekte Statistiken zurückgeben', () => {
      recordLatency(50);
      recordLatency(100);
      const stats = getLatencyStats();
      
      assert.strictEqual(stats.count, 2);
      assert.strictEqual(stats.min, "50.00");
      assert.strictEqual(stats.max, "100.00");
      assert.strictEqual(stats.avg, "75.00");
    });
  });

  describe('Button Mapping Constants', () => {
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

    const DPAD_MAP = {
      10: "up",
      11: "down",
      12: "left",
      13: "right",
    };

    it('sollte gültige Button-Mappings haben', () => {
      assert.strictEqual(BUTTON_MAP[0], "A");
      assert.strictEqual(BUTTON_MAP[1], "B");
      assert.strictEqual(BUTTON_MAP[3], "Y");
    });

    it('sollte gültige D-Pad-Mappings haben', () => {
      assert.strictEqual(DPAD_MAP[10], "up");
      assert.strictEqual(DPAD_MAP[11], "down");
      assert.strictEqual(DPAD_MAP[12], "left");
      assert.strictEqual(DPAD_MAP[13], "right");
    });
  });

  describe('Deadzone Logic', () => {
    const STICK_DEADZONE = 0.05;

    const applyDeadzone = (x, y) => {
      let xVal = Math.abs(x || 0) < STICK_DEADZONE ? 0 : x || 0;
      let yVal = Math.abs(y || 0) < STICK_DEADZONE ? 0 : y || 0;
      return { x: xVal, y: yVal };
    };

    it('sollte Werte unter Deadzone auf 0 setzen', () => {
      const result = applyDeadzone(0.02, 0.03);
      assert.strictEqual(result.x, 0);
      assert.strictEqual(result.y, 0);
    });

    it('sollte Werte über Deadzone behalten', () => {
      const result = applyDeadzone(0.5, -0.5);
      assert.strictEqual(result.x, 0.5);
      assert.strictEqual(result.y, -0.5);
    });

    it('sollte exakt 0.05 behalten', () => {
      const result = applyDeadzone(0.05, 0.05);
      assert.strictEqual(result.x, 0.05);
      assert.strictEqual(result.y, 0.05);
    });
  });
});
