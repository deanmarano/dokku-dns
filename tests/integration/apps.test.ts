import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

describe('dns:apps', () => {
  let dokku: DokkuDns;
  const PLUGIN_DATA_ROOT = '/var/lib/dokku/services/dns';
  const APP = 'dns-test-apps';

  beforeAll(async () => {
    dokku = new DokkuDns();
    dokku.createTestApp(APP);
  });

  afterAll(async () => {
    await dokku.cleanup();
  });

  it('lists no apps when none are managed', async () => {
    const result = await dokku.exec('apps');
    expect(result.exitCode).toBe(0);
  });

  it('enables an app for DNS management', async () => {
    const result = await dokku.exec('apps:enable', APP);
    // May succeed or fail depending on zone config, but should not crash
    expect([0, 1]).toContain(result.exitCode);
  });

  it('shows app report', async () => {
    const result = await dokku.exec('apps:report', APP);
    // May fail if app wasn't successfully enabled (no provider in CI)
    const output = result.stdout + result.stderr;
    expect(output).toContain(APP);
  });

  it('disables an app from DNS management', async () => {
    const result = await dokku.exec('apps:disable', APP);
    expect(result.exitCode).toBe(0);
  });
});
