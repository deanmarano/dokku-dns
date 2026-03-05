import { execSync, spawn, spawnSync } from 'child_process';

const DOKKU_HOST = process.env.DOKKU_HOST || 'local';
const DOKKU_SSH_PORT = process.env.DOKKU_SSH_PORT || '22';
const USE_SUDO = process.env.DOKKU_USE_SUDO === 'true';

export interface ExecResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

export class DokkuDns {
  private apps: string[] = [];

  private isRemote(): boolean {
    return DOKKU_HOST !== 'local' && DOKKU_HOST !== 'localhost' && DOKKU_HOST !== '127.0.0.1';
  }

  private buildCommand(args: string[]): string {
    const argsStr = args.join(' ');
    if (this.isRemote()) {
      return `ssh -o StrictHostKeyChecking=no -p ${DOKKU_SSH_PORT} dokku@${DOKKU_HOST} ${argsStr}`;
    }
    return USE_SUDO ? `sudo dokku ${argsStr}` : `dokku ${argsStr}`;
  }

  private isHarmlessWarning(stderr: string): boolean {
    const stderrLines = stderr.split('\n').filter(l => l.trim());
    return stderrLines.length > 0 && stderrLines.every(
      l => l.includes('main: command not found') ||
           l.includes('Checking nginx status is not possible') ||
           l.trim() === ''
    );
  }

  private spawnAsync(cmd: string): Promise<ExecResult> {
    return new Promise((resolve) => {
      const parts = cmd.split(/\s+/);
      const child = spawn(parts[0], parts.slice(1), {
        stdio: ['inherit', 'pipe', 'pipe'],
      });

      let stdout = '';
      let stderr = '';
      child.stdout.on('data', (data: Buffer) => { stdout += data.toString(); });
      child.stderr.on('data', (data: Buffer) => { stderr += data.toString(); });

      child.on('close', (code) => {
        const exitCode = code ?? 1;
        if (exitCode === 0) {
          resolve({ exitCode: 0, stdout, stderr });
        } else if (stdout.length > 0 && this.isHarmlessWarning(stderr)) {
          resolve({ exitCode: 0, stdout, stderr });
        } else {
          resolve({ exitCode, stdout, stderr });
        }
      });
    });
  }

  /** Execute a dns command and return exit code, stdout, stderr */
  async exec(...args: string[]): Promise<ExecResult> {
    const fullArgs = args[0]?.startsWith('dns:') ? args : ['dns:' + args[0], ...args.slice(1)];
    const cmd = this.buildCommand(fullArgs);
    return this.spawnAsync(cmd);
  }

  /** Run a dokku dns command synchronously */
  run(...args: string[]): string {
    const fullArgs = args[0]?.startsWith('dns:') ? args : ['dns:' + args[0], ...args.slice(1)];
    const cmd = this.buildCommand(fullArgs);
    return this.execSyncTolerant(cmd);
  }

  /** Run a generic dokku command */
  runDokku(...args: string[]): string {
    const cmd = this.buildCommand(args);
    return this.execSyncTolerant(cmd);
  }

  /** Run a generic dokku command async, returning ExecResult */
  async execDokku(...args: string[]): Promise<ExecResult> {
    const cmd = this.buildCommand(args);
    return this.spawnAsync(cmd);
  }

  private execSyncTolerant(cmd: string): string {
    const parts = cmd.split(/\s+/);
    const result = spawnSync(parts[0], parts.slice(1), {
      encoding: 'utf-8',
      stdio: ['inherit', 'pipe', 'pipe'],
    });

    if (result.status === 0) {
      return result.stdout;
    }

    const stderr = result.stderr || '';
    if (this.isHarmlessWarning(stderr)) {
      return result.stdout;
    }

    const error: any = new Error(`Command failed: ${cmd}\n${stderr}`);
    error.status = result.status;
    error.stdout = result.stdout;
    error.stderr = stderr;
    throw error;
  }

  /** Create a test app and track it for cleanup */
  createTestApp(name: string): void {
    this.runDokku('apps:create', name);
    this.apps.push(name);
  }

  /** Destroy a test app */
  destroyTestApp(name: string): void {
    try {
      this.runDokku('apps:destroy', name, '--force');
    } catch {
      // Already destroyed
    }
    this.apps = this.apps.filter(a => a !== name);
  }

  /** Add a domain to an app */
  addDomain(app: string, domain: string): void {
    this.runDokku('domains:add', app, domain);
  }

  /** Remove a domain from an app */
  removeDomain(app: string, domain: string): void {
    this.runDokku('domains:remove', app, domain);
  }

  /** Get domains for an app */
  getAppDomains(app: string): string[] {
    try {
      const output = this.runDokku('domains:report', app);
      const match = output.match(/Domains app vhosts:\s*(.*)/);
      if (match && match[1].trim()) {
        return match[1].trim().split(/\s+/);
      }
      return [];
    } catch {
      return [];
    }
  }

  /** Read a file from the Dokku host */
  readFile(path: string): string {
    if (this.isRemote()) {
      return execSync(
        `ssh -o StrictHostKeyChecking=no -p ${DOKKU_SSH_PORT} dokku@${DOKKU_HOST} cat ${path}`,
        { encoding: 'utf-8' }
      );
    }
    const cmd = USE_SUDO ? `sudo cat ${path}` : `cat ${path}`;
    return execSync(cmd, { encoding: 'utf-8' });
  }

  /** Check if a path exists on the Dokku host */
  pathExists(path: string): boolean {
    try {
      if (this.isRemote()) {
        execSync(
          `ssh -o StrictHostKeyChecking=no -p ${DOKKU_SSH_PORT} dokku@${DOKKU_HOST} test -e ${path}`,
        );
      } else {
        const cmd = USE_SUDO ? `sudo test -e ${path}` : `test -e ${path}`;
        execSync(cmd);
      }
      return true;
    } catch {
      return false;
    }
  }

  /** List files in a directory on the Dokku host */
  listFiles(path: string): string[] {
    try {
      let cmd: string;
      if (this.isRemote()) {
        cmd = `ssh -o StrictHostKeyChecking=no -p ${DOKKU_SSH_PORT} dokku@${DOKKU_HOST} ls ${path}`;
      } else {
        cmd = USE_SUDO ? `sudo ls ${path}` : `ls ${path}`;
      }
      return execSync(cmd, { encoding: 'utf-8' }).trim().split('\n').filter(Boolean);
    } catch {
      return [];
    }
  }

  /** Cleanup all created apps and DNS state */
  async cleanup(): Promise<void> {
    for (const app of [...this.apps].reverse()) {
      try {
        // Disable DNS for the app first
        await this.exec('apps:disable', app);
      } catch {
        // Ignore
      }
      try {
        this.runDokku('apps:destroy', app, '--force');
      } catch {
        // Already destroyed
      }
    }
    this.apps = [];
  }
}
