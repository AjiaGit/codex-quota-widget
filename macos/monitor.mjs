import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { normalizeQuota } from './quota.mjs';
import { queryExternal } from './external.mjs';

const ROOT = dirname(fileURLToPath(import.meta.url));
const HOST = '127.0.0.1';
const PORT = 39224;
const REFRESH_MS = 5 * 60 * 1000;

export function queryAppServer({ command = 'codex', args = ['app-server'], timeoutMs = 20000 } = {}) {
  return new Promise((resolveResult, rejectResult) => {
    let child;
    let settled = false;
    let output;
    let timeout;
    let limits;
    let accountSeen = false;
    let accountPlanType = null;

    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      output?.close();
      child?.kill();
      if (error) rejectResult(error);
      else resolveResult(result);
    };

    try {
      child = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
    } catch (error) {
      finish(error);
      return;
    }

    // Drain diagnostics without copying account details into a log file.
    child.stderr.resume();
    child.on('error', error => finish(error));
    child.on('exit', code => finish(new Error(`Codex App Server 已退出 (${code})`)));
    child.stdin.on('error', error => finish(error));
    output = createInterface({ input: child.stdout });
    output.on('line', line => {
      let message;
      try { message = JSON.parse(line); } catch { return; }
      if (message.id === 0) {
        if (message.error) return finish(new Error(message.error.message || '初始化失败'));
        child.stdin.write(JSON.stringify({ method: 'initialized', params: {} }) + '\n');
        child.stdin.write(JSON.stringify({ method: 'account/rateLimits/read', id: 1 }) + '\n');
        child.stdin.write(JSON.stringify({ method: 'account/read', id: 2, params: { refreshToken: false } }) + '\n');
      } else if (message.id === 1) {
        if (message.error) finish(new Error(message.error.message || '额度查询失败'));
        else limits = message.result;
      } else if (message.id === 2) {
        accountSeen = true;
        accountPlanType = message.result?.account?.planType || null;
      }
      if (limits && accountSeen) finish(null, { ...limits, accountPlanType });
    });
    timeout = setTimeout(() => finish(new Error('Codex App Server 查询超时')), timeoutMs);
    child.stdin.write(JSON.stringify({
      method: 'initialize', id: 0,
      params: { clientInfo: { name: 'codex_weekly_monitor', title: 'Codex Weekly Monitor', version: '1.0.0' } },
    }) + '\n');
  });
}

async function run() {
  let state = { status: 'loading', message: '正在读取额度' };
  let pending = null;
  let externalState = { status: 'loading', lastGlobal: null, forecast: null };
  let externalPending = null;
  let lastExternalFetch = 0;

  const refresh = () => {
    if (pending) return pending;
    pending = (async () => {
      try {
        const result = await queryAppServer();
        const quota = normalizeQuota(result, result.accountPlanType);
        state = quota
          ? { status: 'ok', ...quota, updatedAt: Date.now() }
          : { status: 'unavailable', message: '当前账号未提供七天 Codex 额度' };
      } catch {
        state = { status: 'unavailable', message: '额度暂不可用，请确认 Codex 已登录' };
      } finally {
        pending = null;
      }
      return state;
    })();
    return pending;
  };

  const refreshExternal = (force = false) => {
    if (externalPending) return externalPending;
    if (force && Date.now() - lastExternalFetch < 60 * 1000) return Promise.resolve(externalState);
    lastExternalFetch = Date.now();
    externalPending = (async () => {
      try { externalState = await queryExternal(); }
      catch { externalState = { status: 'unavailable', lastGlobal: null, forecast: null }; }
      finally { externalPending = null; }
      return externalState;
    })();
    return externalPending;
  };

  const files = new Map([
    ['/', ['index.html', 'text/html; charset=utf-8']],
    ['/app.css', ['app.css', 'text/css; charset=utf-8']],
    ['/app.mjs', ['app.mjs', 'text/javascript; charset=utf-8']],
  ]);

  const server = createServer(async (request, response) => {
    const url = new URL(request.url || '/', `http://${HOST}:${PORT}`);
    const hostIsLocal = request.headers.host === `${HOST}:${PORT}`;
    if (!hostIsLocal) {
      response.writeHead(403).end();
      return;
    }
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'");

    if (request.method === 'GET' && url.pathname === '/health') {
      response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ app: 'codex-weekly-monitor' }));
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/usage') {
      if (state.status === 'loading') await refresh();
      response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify(state));
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/external') {
      if (externalState.status === 'loading') await refreshExternal();
      response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify(externalState));
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/refresh') {
      const origin = request.headers.origin;
      if (origin && origin !== `http://${HOST}:${PORT}`) {
        response.writeHead(403).end();
        return;
      }
      await Promise.allSettled([refresh(), refreshExternal(true)]);
      response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify(state));
      return;
    }
    if (request.method === 'GET' && files.has(url.pathname)) {
      const [name, contentType] = files.get(url.pathname);
      try {
        const content = await readFile(join(ROOT, 'public', name));
        response.writeHead(200, { 'Content-Type': contentType });
        response.end(content);
      } catch {
        response.writeHead(500).end('页面文件不可用');
      }
      return;
    }
    response.writeHead(404).end();
  });

  server.listen(PORT, HOST, () => {
    process.stdout.write(`Codex 周额度面板：http://${HOST}:${PORT}/\n`);
    refresh();
    refreshExternal();
  });
  const timer = setInterval(refresh, REFRESH_MS);
  const externalTimer = setInterval(refreshExternal, 10 * 60 * 1000);
  const stop = () => { clearInterval(timer); clearInterval(externalTimer); server.close(() => process.exit(0)); };
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  run().catch(error => { console.error(error.message); process.exitCode = 1; });
}
