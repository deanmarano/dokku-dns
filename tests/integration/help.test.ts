import { describe, it, expect, beforeAll } from 'vitest';
import { DokkuDns } from '../helpers/dokku';

/** Strip ANSI escape codes from output */
function stripAnsi(str: string): string {
  return str.replace(/\u001b\[[0-9;]*m/g, '');
}

describe('dns:help', () => {
  let dokku: DokkuDns;

  beforeAll(() => {
    dokku = new DokkuDns();
  });

  it('shows help output', async () => {
    const result = await dokku.exec('help');
    expect(result.exitCode).toBe(0);
    expect(stripAnsi(result.stdout)).toContain('usage: dokku dns');
  });

  it('shows help for bare dns command', async () => {
    const result = await dokku.execDokku('dns');
    expect(result.exitCode).toBe(0);
    expect(stripAnsi(result.stdout)).toContain('usage: dokku dns');
  });

  it('lists available subcommands', async () => {
    const result = await dokku.exec('help');
    expect(result.exitCode).toBe(0);
    const output = stripAnsi(result.stdout);
    expect(output).toContain('dns:apps');
    expect(output).toContain('dns:zones');
    expect(output).toContain('dns:sync-all');
    expect(output).toContain('dns:ttl');
  });
});
