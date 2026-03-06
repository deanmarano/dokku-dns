import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import { ApiInterceptor } from '../helpers/interceptor';
import { resolve } from 'path';

const PLUGIN_ROOT = resolve(__dirname, '../..');

describe('AWS Route53 provider API calls', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    interceptor.setAwsZones([
      { id: 'Z1TESTZONE', name: 'example.com' },
    ]);
    interceptor.setAwsRecords('Z1TESTZONE', [
      { name: 'app.example.com', type: 'A', value: '10.0.0.1', ttl: 300 },
    ]);
  });

  afterAll(() => {
    // cleanup is per-test via beforeEach creating new interceptor
  });

  it('provider_validate_credentials calls sts get-caller-identity', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_validate_credentials
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.awsCalls();
    const stsCalls = calls.filter(c =>
      c.args?.includes('sts') && c.args?.includes('get-caller-identity')
    );
    expect(stsCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_list_zones calls list-hosted-zones and returns zone names', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_list_zones
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('example.com');

    const calls = interceptor.awsCalls();
    const zoneCalls = calls.filter(c =>
      c.args?.includes('route53') && c.args?.includes('list-hosted-zones')
    );
    expect(zoneCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_get_zone_id returns zone ID for matching domain', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_get_zone_id "example.com"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('Z1TESTZONE');
  });

  it('provider_get_zone_id climbs parent domains', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_get_zone_id "app.api.example.com"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('Z1TESTZONE');
  });

  it('provider_get_record fetches record value', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_get_record "Z1TESTZONE" "app.example.com" "A"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('10.0.0.1');

    const calls = interceptor.awsCalls();
    const recordCalls = calls.filter(c =>
      c.args?.includes('list-resource-record-sets') &&
      c.args?.includes('Z1TESTZONE')
    );
    expect(recordCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_create_record sends UPSERT change batch', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_create_record "Z1TESTZONE" "new.example.com" "A" "10.0.0.2" 600
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c => c.subcommand === 'change-resource-record-sets');
    expect(changeCalls.length).toBe(1);

    const batch = changeCalls[0].change_batch;
    expect(batch).toBeDefined();
    expect(batch.Changes).toHaveLength(1);
    expect(batch.Changes[0].Action).toBe('UPSERT');
    expect(batch.Changes[0].ResourceRecordSet.Name).toBe('new.example.com');
    expect(batch.Changes[0].ResourceRecordSet.Type).toBe('A');
    expect(batch.Changes[0].ResourceRecordSet.TTL).toBe(600);
    expect(batch.Changes[0].ResourceRecordSet.ResourceRecords[0].Value).toBe('10.0.0.2');
  });

  it('provider_delete_record sends DELETE change batch', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_delete_record "Z1TESTZONE" "app.example.com" "A"
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.awsCalls();
    const changeCalls = calls.filter(c => c.subcommand === 'change-resource-record-sets');
    expect(changeCalls.length).toBe(1);

    const batch = changeCalls[0].change_batch;
    expect(batch).toBeDefined();
    expect(batch.Changes).toHaveLength(1);
    expect(batch.Changes[0].Action).toBe('DELETE');
    expect(batch.Changes[0].ResourceRecordSet.Name).toBe('app.example.com');
    expect(batch.Changes[0].ResourceRecordSet.Type).toBe('A');
    expect(batch.Changes[0].ResourceRecordSet.ResourceRecords[0].Value).toBe('10.0.0.1');
  });
});

describe('Cloudflare provider API calls', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    interceptor.setCloudflareZones([
      { id: 'cf-zone-123', name: 'example.com' },
    ]);
    interceptor.setCloudflareRecords([
      { id: 'cf-rec-1', name: 'app.example.com', type: 'A', content: '10.0.0.1', ttl: 300 },
    ]);
  });

  it('provider_validate_credentials calls /user endpoint', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_validate_credentials
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const userCalls = calls.filter(c => c.url?.includes('/user'));
    expect(userCalls.length).toBeGreaterThanOrEqual(1);

    // Should use Bearer token auth
    const authHeaders = userCalls[0].headers?.filter(h => h.includes('Bearer'));
    expect(authHeaders?.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_list_zones calls /zones endpoint', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_list_zones
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('example.com');

    const calls = interceptor.curlCalls();
    const zoneCalls = calls.filter(c => c.url?.includes('/zones') && !c.url?.includes('dns_records'));
    expect(zoneCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_get_zone_id returns zone ID', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_get_zone_id "example.com"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('cf-zone-123');
  });

  it('provider_get_record fetches record from dns_records endpoint', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_get_record "cf-zone-123" "app.example.com" "A"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('10.0.0.1');

    const calls = interceptor.curlCalls();
    const recordCalls = calls.filter(c => c.url?.includes('dns_records'));
    expect(recordCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_create_record POSTs new record to dns_records', () => {
    // Use empty records so the "check existing" step finds nothing
    interceptor.setCloudflareRecords([]);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_create_record "cf-zone-123" "new.example.com" "A" "10.0.0.2" 600
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const postCalls = calls.filter(c => c.method === 'POST' && c.url?.includes('dns_records'));
    expect(postCalls.length).toBe(1);

    // Verify the POST data contains the record details
    expect(postCalls[0].data).toBeDefined();
    expect(postCalls[0].data.name).toBe('new.example.com');
    expect(postCalls[0].data.type).toBe('A');
    expect(postCalls[0].data.content).toBe('10.0.0.2');
    expect(postCalls[0].data.ttl).toBe(600);
  });

  it('provider_create_record PUTs existing record', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_create_record "cf-zone-123" "app.example.com" "A" "10.0.0.99" 300
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const putCalls = calls.filter(c => c.method === 'PUT' && c.url?.includes('dns_records'));
    expect(putCalls.length).toBe(1);
    expect(putCalls[0].url).toContain('cf-rec-1');
  });

  it('provider_delete_record DELETEs by record ID', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_delete_record "cf-zone-123" "app.example.com" "A"
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const deleteCalls = calls.filter(c => c.method === 'DELETE' && c.url?.includes('dns_records'));
    expect(deleteCalls.length).toBe(1);
    expect(deleteCalls[0].url).toContain('cf-rec-1');
  });
});

describe('DigitalOcean provider API calls', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
    interceptor.setDigitalOceanZones([
      { name: 'example.com' },
    ]);
    interceptor.setDigitalOceanRecords('example.com', [
      { id: 12345, name: 'app', type: 'A', data: '10.0.0.1', ttl: 1800 },
    ]);
  });

  it('provider_validate_credentials calls /account endpoint', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_validate_credentials
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const accountCalls = calls.filter(c => c.url?.includes('/account'));
    expect(accountCalls.length).toBeGreaterThanOrEqual(1);

    // Should use Bearer token auth
    const authHeaders = accountCalls[0].headers?.filter(h => h.includes('Bearer'));
    expect(authHeaders?.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_list_zones calls /domains endpoint', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_list_zones
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('example.com');

    const calls = interceptor.curlCalls();
    const domainCalls = calls.filter(c => c.url?.includes('/domains') && !c.url?.includes('/records'));
    expect(domainCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_get_zone_id returns domain name as zone ID', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_get_zone_id "example.com"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('example.com');
  });

  it('provider_get_record fetches record from /domains/records', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_get_record "example.com" "app" "A"
    `);

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('10.0.0.1');

    const calls = interceptor.curlCalls();
    const recordCalls = calls.filter(c => c.url?.includes('/records'));
    expect(recordCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('provider_create_record POSTs new record', () => {
    interceptor.setDigitalOceanRecords('example.com', []);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_create_record "example.com" "new" "A" "10.0.0.2" 3600
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const postCalls = calls.filter(c => c.method === 'POST' && c.url?.includes('/records'));
    expect(postCalls.length).toBe(1);

    expect(postCalls[0].data).toBeDefined();
    expect(postCalls[0].data.name).toBe('new');
    expect(postCalls[0].data.type).toBe('A');
    expect(postCalls[0].data.data).toBe('10.0.0.2');
    expect(postCalls[0].data.ttl).toBe(3600);
  });

  it('provider_create_record PUTs existing record', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_create_record "example.com" "app" "A" "10.0.0.99" 1800
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const putCalls = calls.filter(c => c.method === 'PUT' && c.url?.includes('/records'));
    expect(putCalls.length).toBe(1);
    expect(putCalls[0].url).toContain('12345');
  });

  it('provider_delete_record DELETEs by record ID', () => {
    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_delete_record "example.com" "app" "A"
    `);

    expect(result.exitCode).toBe(0);

    const calls = interceptor.curlCalls();
    const deleteCalls = calls.filter(c => c.method === 'DELETE' && c.url?.includes('/records'));
    expect(deleteCalls.length).toBe(1);
    expect(deleteCalls[0].url).toContain('12345');
  });
});

describe('Error handling - AWS', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
  });

  it('provider_validate_credentials fails with invalid credentials', () => {
    interceptor.setAwsError('sts', 'InvalidClientTokenId', 'The security token included in the request is invalid.');

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=bad-key
      export AWS_SECRET_ACCESS_KEY=bad-secret
      provider_validate_credentials
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('credentials');
  });

  it('provider_list_zones fails with error response', () => {
    interceptor.setAwsError('list-hosted-zones', 'AccessDenied', 'User is not authorized');

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_list_zones
    `);

    expect(result.exitCode).not.toBe(0);
  });

  it('provider_get_record fails for nonexistent record', () => {
    interceptor.setAwsZones([{ id: 'Z1TESTZONE', name: 'example.com' }]);
    interceptor.setAwsRecords('Z1TESTZONE', []);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_get_record "Z1TESTZONE" "nonexistent.example.com" "A"
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('not found');
  });

  it('provider_get_zone_id fails for unknown domain', () => {
    interceptor.setAwsZones([]);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/aws/config.sh"
      source "${PLUGIN_ROOT}/providers/aws/provider.sh"
      export AWS_ACCESS_KEY_ID=test-key
      export AWS_SECRET_ACCESS_KEY=test-secret
      provider_get_zone_id "unknown.example.com"
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('not found');
  });
});

describe('Error handling - Cloudflare', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
  });

  it('provider_validate_credentials fails with invalid token', () => {
    interceptor.setCloudflareError();

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=bad-token
      provider_validate_credentials
    `);

    expect(result.exitCode).not.toBe(0);
  });

  it('provider_list_zones fails with error response', () => {
    interceptor.setCloudflareError();

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=bad-token
      provider_list_zones
    `);

    expect(result.exitCode).not.toBe(0);
  });

  it('provider_get_record fails for nonexistent record', () => {
    interceptor.setCloudflareZones([{ id: 'cf-zone-1', name: 'example.com' }]);
    interceptor.setCloudflareRecords([]);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/cloudflare/config.sh"
      source "${PLUGIN_ROOT}/providers/cloudflare/provider.sh"
      export CLOUDFLARE_API_TOKEN=test-token
      provider_get_record "cf-zone-1" "nonexistent.example.com" "A"
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('not found');
  });
});

describe('Error handling - DigitalOcean', () => {
  let interceptor: ApiInterceptor;

  beforeEach(() => {
    interceptor = new ApiInterceptor();
  });

  it('provider_validate_credentials fails with invalid token', () => {
    interceptor.setDigitalOceanError();

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=bad-token
      provider_validate_credentials
    `);

    expect(result.exitCode).not.toBe(0);
  });

  it('provider_get_record fails for nonexistent record', () => {
    interceptor.setDigitalOceanZones([{ name: 'example.com' }]);
    interceptor.setDigitalOceanRecords('example.com', []);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_get_record "example.com" "nonexistent" "A"
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('not found');
  });

  it('provider_delete_record fails for nonexistent record', () => {
    interceptor.setDigitalOceanZones([{ name: 'example.com' }]);
    interceptor.setDigitalOceanRecords('example.com', []);

    const result = interceptor.run(`
      source "${PLUGIN_ROOT}/providers/digitalocean/config.sh"
      source "${PLUGIN_ROOT}/providers/digitalocean/provider.sh"
      export DIGITALOCEAN_ACCESS_TOKEN=test-token
      provider_delete_record "example.com" "nonexistent" "A"
    `);

    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain('not found');
  });
});
