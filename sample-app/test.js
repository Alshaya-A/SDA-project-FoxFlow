// FoxFlow sample app — automated tests using Node's built-in test runner (no external dependencies)
'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');

// Start the server on a random free port for the tests
process.env.PORT = 0;
const server = require('./server.js');

// Helper: make a request and collect the full response
function request(method, path) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { method, host: '127.0.0.1', port: server.address().port, path },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
      }
    );
    req.on('error', reject);
    req.end();
  });
}

after(() => server.close());

test('GET /health returns 200 and the exact agreed payload', async () => {
  const res = await request('GET', '/health');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body, '{"status":"ok","service":"foxflow-sample"}');
});

test('GET /health returns 503 in the opt-in committee demo mode', async () => {
  process.env.FOXFLOW_DEMO_FAIL = 'true';
  try {
    const res = await request('GET', '/health');
    assert.strictEqual(res.status, 503);
    assert.strictEqual(res.body, '{"status":"error","service":"foxflow-sample","demo":true}');
  } finally {
    delete process.env.FOXFLOW_DEMO_FAIL;
  }
});

test('GET / returns 200 and HTML', async () => {
  const res = await request('GET', '/');
  assert.strictEqual(res.status, 200);
  assert.match(res.headers['content-type'], /text\/html/);
});

test('GET /unknown returns a clean 404', async () => {
  const res = await request('GET', '/unknown');
  assert.strictEqual(res.status, 404);
  assert.strictEqual(res.body, '{"error":"not found"}');
});

test('POST / is rejected with 405', async () => {
  const res = await request('POST', '/');
  assert.strictEqual(res.status, 405);
});
