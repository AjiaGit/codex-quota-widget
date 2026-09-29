import readline from 'node:readline';

let initialized = false;
const lines = readline.createInterface({ input: process.stdin });
for await (const line of lines) {
  const message = JSON.parse(line);
  if (message.method === 'initialize') {
    process.stdout.write(JSON.stringify({ id: message.id, result: {} }) + '\n');
  } else if (message.method === 'initialized') {
    initialized = true;
  } else if (message.method === 'account/rateLimits/read') {
    if (!initialized) throw new Error('missing initialized notification');
    process.stdout.write(JSON.stringify(process.argv.includes('--error')
      ? { id: message.id, error: { code: 401, message: 'not logged in' } }
      : { id: message.id, result: { rateLimitsByLimitId: { codex: {
        primary: { usedPercent: 61, windowDurationMins: 10080, resetsAt: 1791073298 },
      } } } }) + '\n');
  } else if (message.method === 'account/read') {
    process.stdout.write(JSON.stringify({ id: message.id, result: {
      account: { type: 'chatgpt', planType: 'plus' }, requiresOpenaiAuth: true,
    } }) + '\n');
  } else {
    process.stdout.write(JSON.stringify({ id: message.id, error: { code: -1, message: 'unexpected method' } }) + '\n');
  }
}
