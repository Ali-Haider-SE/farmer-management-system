const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');

let server;
const baseUrl = 'http://127.0.0.1:5010';

test.before(async () => {
  server = spawn(process.execPath, ['src/server.js'], {
    cwd: __dirname + '/..',
    env: {
      ...process.env,
      PORT: '5010',
      CORS_ORIGINS: '*',
    },
    stdio: 'ignore',
  });

  const startedAt = Date.now();
  while (Date.now() - startedAt < 5000) {
    try {
      const response = await fetch(`${baseUrl}/api/health`);
      if (response.ok) return;
    } catch (_) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  throw new Error('Test server did not start');
});

test.after(() => {
  server?.kill('SIGTERM');
});

test('public health endpoint is available', async () => {
  const response = await fetch(`${baseUrl}/api/health`);
  assert.equal(response.status, 200);

  const body = await response.json();
  assert.equal(body.success, true);
  assert.equal(body.service, 'Farmer Management API');
});

test('business APIs reject unauthenticated requests', async () => {
  const response = await fetch(`${baseUrl}/api/farmers`);
  assert.equal(response.status, 401);

  const body = await response.json();
  assert.equal(body.success, false);
  assert.equal(body.message, 'Authentication required');
});

test('database health endpoint is protected', async () => {
  const response = await fetch(`${baseUrl}/api/health/db`);
  assert.equal(response.status, 401);
});
