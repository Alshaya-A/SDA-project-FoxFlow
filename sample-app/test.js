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

test('GET /api/dashboard fails safely when GitLab integration is unavailable', async () => {
  const res = await request('GET', '/api/dashboard');
  assert.strictEqual(res.status, 503);
  assert.deepStrictEqual(JSON.parse(res.body).status, 'unavailable');
  assert.doesNotMatch(res.body, /token/i);
});

test('GET /api/dashboard returns a sanitized live pipeline summary', async () => {
  const originalFetch = global.fetch;
  process.env.GITLAB_API_URL = 'http://gitlab.test/api/v4';
  process.env.GITLAB_PROJECT_ID = '7';
  process.env.GITLAB_API_TOKEN = 'test-secret-that-must-not-leak';
  const pipeline = {
    id: 101,
    iid: 25,
    status: 'success',
    ref: 'main',
    sha: 'abc123',
    web_url: 'http://gitlab.test/pipelines/101',
    created_at: '2026-09-25T10:00:00Z',
    updated_at: '2026-09-25T10:05:00Z',
    duration: 300,
  };
  const jobs = ['build', 'test', 'security_scan', 'deploy', 'notify_success'].map((name, index) => ({
    id: 200 + index,
    name,
    stage: name,
    status: 'success',
    duration: 20,
    created_at: `2026-09-25T10:0${index}:00Z`,
    started_at: `2026-09-25T10:0${index}:00Z`,
    finished_at: `2026-09-25T10:0${index + 1}:00Z`,
    web_url: `http://gitlab.test/jobs/${200 + index}`,
    runner: { id: 1, status: 'online', online: true },
  }));

  global.fetch = async (url, options) => {
    assert.strictEqual(options.headers['PRIVATE-TOKEN'], process.env.GITLAB_API_TOKEN);
    let value;
    if (url.endsWith('/projects/7')) value = { name: 'sample-app', path_with_namespace: 'foxflow/sample-app', default_branch: 'main', web_url: 'http://gitlab.test/foxflow/sample-app' };
    else if (url.includes('/pipelines?')) value = [pipeline];
    else if (url.endsWith('/pipelines/101')) value = pipeline;
    else if (url.includes('/pipelines/101/jobs')) value = jobs;
    else if (url.endsWith('/artifacts/trivy-report.json')) value = { Results: [{ Vulnerabilities: [{ Severity: 'LOW' }] }] };
    else throw new Error(`Unexpected GitLab request: ${url}`);
    return new Response(JSON.stringify(value), { status: 200 });
  };

  try {
    const res = await request('GET', '/api/dashboard');
    assert.strictEqual(res.status, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.pipeline.iid, 25);
    assert.strictEqual(body.pipeline.status, 'success');
    assert.strictEqual(body.pipeline.jobs.length, 5);
    assert.deepStrictEqual(body.security.counts, { critical: 0, high: 0, medium: 0, low: 1 });
    assert.strictEqual(body.system.runners.online, 1);
    assert.doesNotMatch(res.body, /test-secret-that-must-not-leak/);
  } finally {
    global.fetch = originalFetch;
    delete process.env.GITLAB_API_URL;
    delete process.env.GITLAB_PROJECT_ID;
    delete process.env.GITLAB_API_TOKEN;
  }
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
