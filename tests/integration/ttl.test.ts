import { describe, it, expect, beforeAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

describe('dns:ttl', () => {
  let dokku: DokkuDns;
  let originalTtl: string;

  beforeAll(() => {
    dokku = new DokkuDns();
    try {
      originalTtl = dokku.run('ttl').trim();
    } catch {
      originalTtl = '';
    }
  });

  afterAll(() => {
    // Restore original TTL if we changed it
    if (originalTtl && originalTtl.match(/\d+/)) {
      const match = originalTtl.match(/(\d+)/);
      if (match) {
        try {
          dokku.run('ttl', match[1]);
        } catch {
          // Ignore
        }
      }
    }
  });

  it('shows current TTL', async () => {
    const result = await dokku.exec('ttl');
    expect(result.exitCode).toBe(0);
  });

  it('sets a new TTL value', async () => {
    const result = await dokku.exec('ttl', '600');
    expect(result.exitCode).toBe(0);

    const check = await dokku.exec('ttl');
    expect(check.stdout).toContain('600');
  });
});
