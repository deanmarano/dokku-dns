import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

describe('dns:providers:verify', () => {
  let dokku: DokkuDns;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  it('runs provider verification', async () => {
    const result = await dokku.exec('providers:verify');
    // Will fail if no providers configured, but should not crash
    expect(result).toBeDefined();
  });
});

describe('dns:records (mock provider)', {
  skip: !process.env.MOCK_API_KEY,
}, () => {
  let dokku: DokkuDns;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  it('creates a DNS record via mock provider', async () => {
    const result = await dokku.exec('records:create', 'test.example.com', 'A', '1.2.3.4');
    expect(result.exitCode).toBe(0);
  });

  it('gets a DNS record via mock provider', async () => {
    const result = await dokku.exec('records:get', 'test.example.com', 'A');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('1.2.3.4');
  });

  it('deletes a DNS record via mock provider', async () => {
    const result = await dokku.exec('records:delete', 'test.example.com', 'A');
    expect(result.exitCode).toBe(0);
  });
});

describe('dns:records (AWS Route53)', {
  skip: !process.env.AWS_ACCESS_KEY_ID || !process.env.DNS_TEST_ZONE,
}, () => {
  let dokku: DokkuDns;
  const testZone = process.env.DNS_TEST_ZONE!;
  const testDomain = `vitest-${Date.now()}.${testZone}`;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  afterAll(async () => {
    // Clean up test record
    try {
      await dokku.exec('records:delete', testDomain, 'A');
    } catch {
      // Ignore
    }
  });

  it('creates an A record', async () => {
    const result = await dokku.exec('records:create', testDomain, 'A', '93.184.216.34');
    expect(result.exitCode).toBe(0);
  });

  it('reads the created A record', async () => {
    const result = await dokku.exec('records:get', testDomain, 'A');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('93.184.216.34');
  });

  it('deletes the A record', async () => {
    const result = await dokku.exec('records:delete', testDomain, 'A');
    expect(result.exitCode).toBe(0);
  });
});

describe('dns:records (Cloudflare)', {
  skip: !process.env.CLOUDFLARE_API_TOKEN || !process.env.DNS_TEST_ZONE,
}, () => {
  let dokku: DokkuDns;
  const testZone = process.env.DNS_TEST_ZONE!;
  const testDomain = `vitest-${Date.now()}.${testZone}`;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  afterAll(async () => {
    try {
      await dokku.exec('records:delete', testDomain, 'A');
    } catch {
      // Ignore
    }
  });

  it('creates an A record', async () => {
    const result = await dokku.exec('records:create', testDomain, 'A', '93.184.216.34');
    expect(result.exitCode).toBe(0);
  });

  it('reads the created A record', async () => {
    const result = await dokku.exec('records:get', testDomain, 'A');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('93.184.216.34');
  });

  it('deletes the A record', async () => {
    const result = await dokku.exec('records:delete', testDomain, 'A');
    expect(result.exitCode).toBe(0);
  });
});

describe('dns:records (DigitalOcean)', {
  skip: !process.env.DIGITALOCEAN_TOKEN || !process.env.DNS_TEST_ZONE,
}, () => {
  let dokku: DokkuDns;
  const testZone = process.env.DNS_TEST_ZONE!;
  const testDomain = `vitest-${Date.now()}.${testZone}`;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  afterAll(async () => {
    try {
      await dokku.exec('records:delete', testDomain, 'A');
    } catch {
      // Ignore
    }
  });

  it('creates an A record', async () => {
    const result = await dokku.exec('records:create', testDomain, 'A', '93.184.216.34');
    expect(result.exitCode).toBe(0);
  });

  it('reads the created A record', async () => {
    const result = await dokku.exec('records:get', testDomain, 'A');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('93.184.216.34');
  });

  it('deletes the A record', async () => {
    const result = await dokku.exec('records:delete', testDomain, 'A');
    expect(result.exitCode).toBe(0);
  });
});
