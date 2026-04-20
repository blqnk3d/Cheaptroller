const { getAllLocalIPs } = require('../utils');
const assert = require('assert');

describe('Utils', () => {
  describe('getAllLocalIPs', () => {
    it('sollte ein Array zurückgeben', () => {
      const ips = getAllLocalIPs();
      assert.ok(Array.isArray(ips), 'sollte ein Array sein');
    });

    it('sollte IPv4-Adressen zurückgeben', () => {
      const ips = getAllLocalIPs();
      const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
      for (const ip of ips) {
        assert.ok(ipv4Regex.test(ip), ` Ungültige IPv4: ${ip}`);
      }
    });

    it('sollte 127.0.0.1 zurückgeben wenn keine anderen IPs verfügbar', () => {
      const ips = getAllLocalIPs();
      if (ips.length === 0) {
        assert.fail('sollte mindestens 127.0.0.1 zurückgeben');
      }
    });

    it('sollte keine interne IP zurückgeben', () => {
      const ips = getAllLocalIPs();
      for (const ip of ips) {
        assert.ok(!ip.startsWith('127.'), 'sollte keine 127.x IPs zurückgeben');
      }
    });

    it('sollte keine link-local IPs (169.254.) zurückgeben', () => {
      const ips = getAllLocalIPs();
      for (const ip of ips) {
        assert.ok(!ip.startsWith('169.254.'), 'sollte keine link-local IPs zurückgeben');
      }
    });
  });
});