import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { ApiInterceptor } from '../helpers/interceptor';
import { resolve } from 'path';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const PLUGIN_ROOT = resolve(__dirname, '../..');

/**
 * Helper to set up a temp PLUGIN_DATA_ROOT with multi-provider zone mappings
 * pre-populated, so subcommands/adapter can find providers without discovery.
 */
function setupPluginData(tmpDir: string, opts: {
  provider: string;
  zones: Array<{ name: string; id?: string }>;
  apps?: Record<string, { domains: string[]; ttls?: Record<string, number> }>;
  globalTtl?: number;
  enabledZones?: string[];
}) {
  const dataRoot = join(tmpDir, 'dns-data');
  mkdirSync(dataRoot, { recursive: true });

  // Set up multi-provider zone mappings
  const mpDir = join(dataRoot, '.multi-provider');
  mkdirSync(join(mpDir, 'providers'), { recursive: true });
  mkdirSync(join(mpDir, 'zones'), { recursive: true });

  // Write provider -> zones mapping
  const zoneNames = opts.zones.map(z => z.name).join('\n');
  writeFileSync(join(mpDir, 'providers', opts.provider), zoneNames);

  // Write zone -> provider reverse mappings
  for (const zone of opts.zones) {
    writeFileSync(join(mpDir, 'zones', zone.name), opts.provider);
  }

  // Set up app data
  if (opts.apps) {
    for (const [app, appData] of Object.entries(opts.apps)) {
      const appDir = join(dataRoot, app);
      mkdirSync(appDir, { recursive: true });
      writeFileSync(join(appDir, 'DOMAINS'), appData.domains.join('\n') + '\n');

      if (appData.ttls) {
        const ttlLines = Object.entries(appData.ttls)
          .map(([domain, ttl]) => `${domain}:${ttl}`)
          .join('\n');
        writeFileSync(join(appDir, 'DOMAIN_TTLS'), ttlLines + '\n');
      }
    }
  }

  // Global TTL
  if (opts.globalTtl) {
    writeFileSync(join(dataRoot, 'GLOBAL_TTL'), String(opts.globalTtl));
  }

  // Enabled zones
  if (opts.enabledZones) {
    writeFileSync(join(dataRoot, 'ENABLED_ZONES'), opts.enabledZones.join('\n'));
  }

  // LINKS file
  if (opts.apps) {
    writeFileSync(join(dataRoot, 'LINKS'), Object.keys(opts.apps).join('\n'));
  }

  return dataRoot;
}

describe('E2E: App sync flow (AWS)', () => {
  let interceptor: ApiInterceptor;
  let dataRoot: string;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));

    interceptor.setAwsZones([{ id: 'Z1TEST', name: 'example.com' }]);
    interceptor.setAwsRecords('Z1TEST', []);

    dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
      apps: {
        'myapp': { domains: ['myapp.example.com', 'api.example.com'] },
      },
    });
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('syncs app domains and creates A records via AWS API', () => {
    const env = interceptor.env();
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('myapp.example.com');
    expect(result.stdout).toContain('api.example.com');
    expect(result.stdout).toContain('Synced: 2');
    expect(result.stdout).toContain('Failed: 0');

    // Verify AWS API calls were made
    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c =>
      c.args?.includes('route53') && c.args?.includes('change-resource-record-sets')
    );
    expect(changeCalls.length).toBeGreaterThanOrEqual(2);
  });

  it('skips domains already pointing to correct IP', () => {
    // Set up records that already point to our server IP
    interceptor.setAwsRecords('Z1TEST', [
      { name: 'myapp.example.com', type: 'A', value: '10.0.0.42' },
    ]);

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('already correct');
    // api.example.com should still be created
    expect(result.stdout).toContain('Synced: 2');
  });

  it('reports update when record has wrong IP', () => {
    interceptor.setAwsRecords('Z1TEST', [
      { name: 'myapp.example.com', type: 'A', value: '10.0.0.99' },
    ]);

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('updated from 10.0.0.99');
  });

  it('fails when app is not in DNS management', () => {
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync nonexistent-app
    `);

    expect(result.exitCode).toBe(1);
    expect(result.stdout + result.stderr).toContain('not in DNS management');
  });
});

describe('E2E: App sync with domain-specific TTL', () => {
  let interceptor: ApiInterceptor;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));
    interceptor.setAwsZones([{ id: 'Z1TEST', name: 'example.com' }]);
    interceptor.setAwsRecords('Z1TEST', []);
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('uses domain-specific TTL when configured', () => {
    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
      apps: {
        'myapp': {
          domains: ['myapp.example.com'],
          ttls: { 'myapp.example.com': 600 },
        },
      },
    });

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Synced: 1');

    // Check the change batch includes TTL 600
    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c => c.change_batch);
    expect(changeCalls.length).toBeGreaterThanOrEqual(1);

    const batch = changeCalls[0].change_batch;
    if (batch?.Changes?.[0]?.ResourceRecordSet?.TTL) {
      expect(batch.Changes[0].ResourceRecordSet.TTL).toBe(600);
    }
  });

  it('falls back to global TTL when no domain TTL set', () => {
    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
      apps: {
        'myapp': { domains: ['myapp.example.com'] },
      },
      globalTtl: 900,
    });

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c => c.change_batch);
    expect(changeCalls.length).toBeGreaterThanOrEqual(1);

    const batch = changeCalls[0].change_batch;
    if (batch?.Changes?.[0]?.ResourceRecordSet?.TTL) {
      expect(batch.Changes[0].ResourceRecordSet.TTL).toBe(900);
    }
  });
});

describe('E2E: Record CRUD lifecycle (Cloudflare)', () => {
  let interceptor: ApiInterceptor;
  let dataRoot: string;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));

    interceptor.setCloudflareZones([{ id: 'cf-zone-1', name: 'example.com' }]);

    dataRoot = setupPluginData(tmpDir, {
      provider: 'cloudflare',
      zones: [{ name: 'example.com' }],
    });
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('creates a record via records:create subcommand', () => {
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export CLOUDFLARE_API_TOKEN=test-token
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com A 1.2.3.4 --force
    `);

    expect(result.exitCode).toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('test.example.com');
    expect(output).toContain('created successfully');

    // Verify Cloudflare API calls
    const calls = interceptor.curlCalls();
    // Should have called zones API and dns_records API
    const zoneCalls = calls.filter(c => c.url?.includes('api.cloudflare.com'));
    expect(zoneCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('creates a record with custom TTL', () => {
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export CLOUDFLARE_API_TOKEN=test-token
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com A 1.2.3.4 --ttl 600 --force
    `);

    expect(result.exitCode).toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('TTL:   600');
  });

  it('rejects invalid record types', () => {
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export CLOUDFLARE_API_TOKEN=test-token
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com INVALID 1.2.3.4 --force
    `);

    expect(result.exitCode).not.toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('Unsupported record type');
  });

  it('rejects TTL out of range', () => {
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export CLOUDFLARE_API_TOKEN=test-token
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com A 1.2.3.4 --ttl 10 --force
    `);

    expect(result.exitCode).not.toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('TTL must be between');
  });
});

describe('E2E: Record CRUD lifecycle (DigitalOcean)', () => {
  let interceptor: ApiInterceptor;
  let dataRoot: string;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));

    interceptor.setDigitalOceanZones([{ name: 'example.com' }]);

    dataRoot = setupPluginData(tmpDir, {
      provider: 'digitalocean',
      zones: [{ name: 'example.com' }],
    });
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('creates a record via DigitalOcean API', () => {
    // Make AWS and CF fail so only DO is discovered
    interceptor.setAwsError('sts', 'InvalidClientTokenId', 'invalid');
    interceptor.setCloudflareError();

    const result = interceptor.run(`
      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com A 1.2.3.4 --force
    `);

    expect(result.exitCode).toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('created successfully');

    // Verify DO API calls
    const calls = interceptor.curlCalls();
    const doCalls = calls.filter(c => c.url?.includes('api.digitalocean.com'));
    expect(doCalls.length).toBeGreaterThanOrEqual(1);
  });
});

describe('E2E: Multi-provider zone routing', () => {
  let interceptor: ApiInterceptor;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));

    // Set up both AWS and Cloudflare with different zones
    interceptor.setAwsZones([{ id: 'Z1AWS', name: 'aws-domain.com' }]);
    interceptor.setAwsRecords('Z1AWS', []);
    interceptor.setCloudflareZones([{ id: 'cf-zone-1', name: 'cf-domain.com' }]);
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('routes domains to correct providers based on zone mappings', () => {
    // Set up two zones with different providers
    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws', // primary, but we'll add CF mapping too
      zones: [{ name: 'aws-domain.com' }],
      apps: {
        'myapp': { domains: ['app.aws-domain.com'] },
      },
    });

    // Add Cloudflare zone mapping
    writeFileSync(join(dataRoot, '.multi-provider', 'zones', 'cf-domain.com'), 'cloudflare');
    const cfProviderFile = join(dataRoot, '.multi-provider', 'providers', 'cloudflare');
    writeFileSync(cfProviderFile, 'cf-domain.com');

    // Sync app with AWS domain
    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Synced: 1');

    // Verify AWS was called (not Cloudflare)
    const awsCalls = interceptor.awsCalls();
    const cfCalls = interceptor.curlCalls().filter(c =>
      c.url?.includes('api.cloudflare.com')
    );

    expect(awsCalls.length).toBeGreaterThan(0);
    expect(cfCalls.length).toBe(0);
  });
});

describe('E2E: Error handling', () => {
  let interceptor: ApiInterceptor;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('handles domain with no matching zone gracefully', () => {
    interceptor.setAwsZones([{ id: 'Z1TEST', name: 'example.com' }]);
    interceptor.setAwsRecords('Z1TEST', []);

    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
      apps: {
        'myapp': { domains: ['app.unknown-zone.com'] },
      },
    });

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    // Should fail because domain has no zone
    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain('no zone');
    expect(result.stdout).toContain('Failed: 1');
  });

  it('fails when no provider is configured', () => {
    // Set up data root with NO multi-provider zone mappings
    const dataRoot = join(tmpDir, 'dns-data');
    mkdirSync(join(dataRoot, 'myapp'), { recursive: true });
    writeFileSync(join(dataRoot, 'myapp', 'DOMAINS'), 'app.example.com\n');

    // Make all providers fail credential validation
    interceptor.setAwsError('sts', 'InvalidClientTokenId', 'invalid');
    interceptor.setCloudflareError();
    interceptor.setDigitalOceanError();

    const result = interceptor.run(`
      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL DIGITALOCEAN_TOKEN DIGITALOCEAN_ACCESS_TOKEN
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export DNS_TEST_SERVER_IP=10.0.0.42
      bash "${PLUGIN_ROOT}/subcommands/apps_sync" dns:apps:sync myapp
    `);

    expect(result.exitCode).toBe(1);
    const output = result.stdout + result.stderr;
    expect(output).toContain('no DNS provider');
  });

  it('records:create fails with missing arguments', () => {
    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
    });

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.example.com
    `);

    expect(result.exitCode).not.toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('Usage');
  });

  it('records:create fails for domain with no provider', () => {
    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'other.com' }],
    });

    const result = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      bash "${PLUGIN_ROOT}/subcommands/records_create" dns:records:create test.nomatch.com A 1.2.3.4 --force
    `);

    expect(result.exitCode).not.toBe(0);
    const output = result.stdout + result.stderr;
    expect(output).toContain('No provider found');
  });
});

describe('E2E: Adapter-level record operations', () => {
  let interceptor: ApiInterceptor;
  let tmpDir: string;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    tmpDir = mkdtempSync(join(tmpdir(), 'dns-e2e-'));
    interceptor.setAwsZones([{ id: 'Z1TEST', name: 'example.com' }]);
  });

  afterEach(() => {
    interceptor.cleanup();
  });

  it('creates and retrieves a record through adapter layer', () => {
    interceptor.setAwsRecords('Z1TEST', []);

    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
    });

    // Create a record through the adapter
    const createResult = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      source "${PLUGIN_ROOT}/providers/adapter.sh"
      init_provider_system
      dns_create_record "test.example.com" "A" "10.0.0.1" "300"
    `);

    expect(createResult.exitCode).toBe(0);

    // Verify the change-resource-record-sets call was made
    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c =>
      c.args?.includes('change-resource-record-sets')
    );
    expect(changeCalls.length).toBe(1);
  });

  it('deletes a record through adapter layer', () => {
    interceptor.setAwsRecords('Z1TEST', [
      { name: 'old.example.com', type: 'A', value: '10.0.0.99' },
    ]);

    const dataRoot = setupPluginData(tmpDir, {
      provider: 'aws',
      zones: [{ name: 'example.com' }],
    });

    const deleteResult = interceptor.run(`
      export PLUGIN_DATA_ROOT="${dataRoot}"
      export DNS_ROOT="${dataRoot}"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      source "${PLUGIN_ROOT}/providers/adapter.sh"
      init_provider_system
      dns_delete_record "old.example.com" "A"
    `);

    expect(deleteResult.exitCode).toBe(0);

    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c =>
      c.args?.includes('change-resource-record-sets')
    );
    expect(changeCalls.length).toBe(1);
  });
});
