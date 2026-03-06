import { describe, it, expect, beforeAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

/** Strip ANSI escape codes from output */
function stripAnsi(str: string): string {
  return str.replace(/\u001b\[[0-9;]*m/g, '');
}

describe('dns:zones', () => {
  let dokku: DokkuDns;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  it('lists zones', async () => {
    const result = await dokku.exec('zones');
    expect(result.exitCode).toBe(0);
  });

  it('rejects enabling a non-existent zone', async () => {
    const result = await dokku.exec('zones:enable', 'fake-zone.invalid');
    expect(result.exitCode).not.toBe(0);
  });

  it('handles disabling a non-enabled zone gracefully', async () => {
    const result = await dokku.exec('zones:disable', 'fake-zone.invalid');
    // Should succeed (no-op) or fail with a descriptive message, not crash
    expect(typeof result.exitCode).toBe('number');
    const output = result.stdout + result.stderr;
    expect(output.length).toBeGreaterThan(0);
  });
});

describe('dns:zones (with real provider)', {
  skip: !process.env.DNS_TEST_ZONE,
}, () => {
  let dokku: DokkuDns;
  const testZone = process.env.DNS_TEST_ZONE!;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  afterAll(async () => {
    try {
      dokku.run('zones:disable', testZone);
    } catch {
      // Ignore
    }
  });

  it('enables a real zone', async () => {
    const result = await dokku.exec('zones:enable', testZone);
    expect(result.exitCode).toBe(0);
  });

  it('lists zones and shows the enabled zone', async () => {
    const result = await dokku.exec('zones');
    expect(result.exitCode).toBe(0);
    expect(stripAnsi(result.stdout)).toContain(testZone);
  });

  it('disables the zone', async () => {
    const result = await dokku.exec('zones:disable', testZone);
    expect(result.exitCode).toBe(0);
  });
});
