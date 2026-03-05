import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

describe('dns:triggers', () => {
  let dokku: DokkuDns;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  afterAll(async () => {
    // Ensure triggers are disabled after tests
    try {
      dokku.run('triggers:disable');
    } catch {
      // Ignore
    }
  });

  it('shows trigger status', async () => {
    const result = await dokku.exec('triggers');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DNS automatic management');
  });

  it('enables triggers', async () => {
    const result = await dokku.exec('triggers:enable');
    expect(result.exitCode).toBe(0);

    const status = await dokku.exec('triggers');
    expect(status.stdout).toContain('enabled');
  });

  it('disables triggers', async () => {
    const result = await dokku.exec('triggers:disable');
    expect(result.exitCode).toBe(0);

    const status = await dokku.exec('triggers');
    expect(status.stdout).toContain('disabled');
  });
});
