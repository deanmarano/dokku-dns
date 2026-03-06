import { execSync, spawnSync } from 'child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

export interface InterceptedCall {
  timestamp: string;
  command: string;
  method?: string;
  url?: string;
  args?: string[];
  data?: any;
  headers?: string[];
  subcommand?: string;
  change_batch?: any;
}

/**
 * Sets up mock `aws` and `curl` binaries on PATH that log all calls
 * and return canned responses. Use this to test provider API interactions
 * without hitting real services.
 */
export class ApiInterceptor {
  private tmpDir: string;
  private binDir: string;
  private responsesDir: string;
  private awsLogFile: string;
  private curlLogFile: string;
  private originalPath: string;

  constructor() {
    this.tmpDir = mkdtempSync(join(tmpdir(), 'dns-interceptor-'));
    this.binDir = join(this.tmpDir, 'bin');
    this.responsesDir = join(this.tmpDir, 'responses');
    this.awsLogFile = join(this.tmpDir, 'aws-calls.jsonl');
    this.curlLogFile = join(this.tmpDir, 'curl-calls.jsonl');
    this.originalPath = process.env.PATH || '';

    mkdirSync(this.binDir, { recursive: true });
    mkdirSync(this.responsesDir, { recursive: true });

    // Find the mock scripts relative to this file
    const helpersDir = __dirname;
    const mockAwsSrc = join(helpersDir, 'mock-aws.sh');
    const mockCurlSrc = join(helpersDir, 'mock-curl.sh');

    // Create symlinks in bin dir named `aws` and `curl`
    execSync(`cp "${mockAwsSrc}" "${this.binDir}/aws" && chmod +x "${this.binDir}/aws"`);
    execSync(`cp "${mockCurlSrc}" "${this.binDir}/curl" && chmod +x "${this.binDir}/curl"`);
  }

  /** Get environment variables that activate the interceptor */
  env(): Record<string, string> {
    return {
      PATH: `${this.binDir}:${this.originalPath}`,
      MOCK_AWS_LOG: this.awsLogFile,
      MOCK_AWS_RESPONSES_DIR: this.responsesDir,
      MOCK_CURL_LOG: this.curlLogFile,
      MOCK_CURL_RESPONSES_DIR: this.responsesDir,
    };
  }

  /** Run a shell command with the interceptor active */
  run(cmd: string): { exitCode: number; stdout: string; stderr: string } {
    const env = { ...process.env, ...this.env() };
    const result = spawnSync('bash', ['-c', cmd], {
      encoding: 'utf-8',
      stdio: ['inherit', 'pipe', 'pipe'],
      env,
    });
    return {
      exitCode: result.status ?? 1,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  }

  /** Set a canned response for AWS list-hosted-zones */
  setAwsZones(zones: Array<{ id: string; name: string }>): void {
    const response = {
      HostedZones: zones.map(z => ({
        Id: `/hostedzone/${z.id}`,
        Name: `${z.name}.`,
        CallerReference: 'mock',
        Config: { PrivateZone: false },
      })),
    };
    writeFileSync(join(this.responsesDir, 'list-hosted-zones.json'), JSON.stringify(response));
  }

  /** Set canned records for a specific zone */
  setAwsRecords(zoneId: string, records: Array<{ name: string; type: string; value: string; ttl?: number }>): void {
    const response = {
      ResourceRecordSets: records.map(r => ({
        Name: `${r.name}.`,
        Type: r.type,
        TTL: r.ttl ?? 300,
        ResourceRecords: [{ Value: r.value }],
      })),
    };
    writeFileSync(join(this.responsesDir, `list-records-${zoneId}.json`), JSON.stringify(response));
  }

  /** Set a canned response for Cloudflare zones */
  setCloudflareZones(zones: Array<{ id: string; name: string }>): void {
    const response = {
      success: true,
      result: zones.map(z => ({ id: z.id, name: z.name })),
    };
    writeFileSync(join(this.responsesDir, 'cf-zones.json'), JSON.stringify(response));
  }

  /** Set canned DNS records for Cloudflare */
  setCloudflareRecords(records: Array<{ id: string; name: string; type: string; content: string; ttl?: number }>): void {
    const response = {
      success: true,
      result: records.map(r => ({
        id: r.id,
        name: r.name,
        type: r.type,
        content: r.content,
        ttl: r.ttl ?? 300,
      })),
    };
    writeFileSync(join(this.responsesDir, 'cf-dns-records.json'), JSON.stringify(response));
  }

  /** Get all intercepted AWS CLI calls */
  awsCalls(): InterceptedCall[] {
    return this.readLog(this.awsLogFile);
  }

  /** Get all intercepted curl calls */
  curlCalls(): InterceptedCall[] {
    return this.readLog(this.curlLogFile);
  }

  /** Get all intercepted calls (both aws and curl) */
  allCalls(): InterceptedCall[] {
    return [...this.awsCalls(), ...this.curlCalls()].sort(
      (a, b) => a.timestamp.localeCompare(b.timestamp)
    );
  }

  /** Clear all intercepted calls */
  clearCalls(): void {
    if (existsSync(this.awsLogFile)) unlinkSync(this.awsLogFile);
    if (existsSync(this.curlLogFile)) unlinkSync(this.curlLogFile);
  }

  /** Set a canned response for DigitalOcean domains (zones) */
  setDigitalOceanZones(zones: Array<{ name: string }>): void {
    const response = {
      domains: zones.map(z => ({ name: z.name })),
    };
    writeFileSync(join(this.responsesDir, 'do-domains.json'), JSON.stringify(response));
  }

  /** Set canned DNS records for a DigitalOcean domain */
  setDigitalOceanRecords(domain: string, records: Array<{ id: number; name: string; type: string; data: string; ttl?: number }>): void {
    const response = {
      domain_records: records.map(r => ({
        id: r.id,
        name: r.name,
        type: r.type,
        data: r.data,
        ttl: r.ttl ?? 1800,
      })),
    };
    writeFileSync(join(this.responsesDir, `do-records-${domain}.json`), JSON.stringify(response));
  }

  /** Set a canned error response for AWS */
  setAwsError(command: string, errorCode: string, errorMessage: string): void {
    const response = { Error: { Code: errorCode, Message: errorMessage } };
    writeFileSync(join(this.responsesDir, `aws-error-${command}.json`), JSON.stringify(response));
  }

  /** Set a canned error response for Cloudflare */
  setCloudflareError(): void {
    writeFileSync(join(this.responsesDir, 'cf-error'), '1');
  }

  /** Set a canned error response for DigitalOcean */
  setDigitalOceanError(): void {
    writeFileSync(join(this.responsesDir, 'do-error'), '1');
  }

  /** Clean up temp directory */
  cleanup(): void {
    execSync(`rm -rf "${this.tmpDir}"`);
  }

  private readLog(file: string): InterceptedCall[] {
    if (!existsSync(file)) return [];
    return readFileSync(file, 'utf-8')
      .trim()
      .split('\n')
      .filter(Boolean)
      .map(line => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter((c): c is InterceptedCall => c !== null);
  }
}
