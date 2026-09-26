// FoxFlow dashboard and health API — Node built-in modules only.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');
const INDEX_HTML = fs.readFileSync(path.join(PUBLIC_DIR, 'index.html'));
const DASHBOARD_HTML = fs.readFileSync(path.join(PUBLIC_DIR, 'dashboard.html'));
const LOGIN_HTML = fs.readFileSync(path.join(PUBLIC_DIR, 'login.html'), 'utf8');

// The exact health payload is a shared CI contract. Do not change it.
const HEALTH_BODY = JSON.stringify({ status: 'ok', service: 'foxflow-sample' });
const DASHBOARD_CACHE_MS = 10_000;
const REQUEST_TIMEOUT_MS = 12_000;
const TERMINAL_STATUSES = new Set(['success', 'failed', 'canceled', 'skipped', 'manual']);
const SESSION_COOKIE = 'foxflow_session';
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;
const LOGIN_BODY_LIMIT = 4096;
const LOGIN_FAILURE_LIMIT = 5;
const LOGIN_LOCK_MS = 10 * 60 * 1000;

let dashboardCache = { expiresAt: 0, value: null, pending: null };
const loginFailures = new Map();

function loadAuthConfig() {
  const secret = process.env.DASHBOARD_SESSION_SECRET || '';
  let entries = [];
  try {
    entries = JSON.parse(process.env.DASHBOARD_USERS_JSON || '[]');
  } catch (_) {
    console.error('DASHBOARD_USERS_JSON is invalid JSON; dashboard access is disabled.');
  }
  const users = new Map();
  for (const entry of Array.isArray(entries) ? entries : []) {
    const username = String(entry.username || '').toLowerCase();
    if (!/^[a-z0-9._-]{2,40}$/.test(username)) continue;
    if (!entry.salt || !entry.hash || !entry.name) continue;
    users.set(username, {
      username,
      name: cleanText(entry.name, 80),
      salt: String(entry.salt),
      hash: String(entry.hash),
    });
  }
  return { secret, users, ready: secret.length >= 32 && users.size > 0 };
}

const dashboardAuth = loadAuthConfig();

function sendJson(res, status, value) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(value));
}

function sendHtml(res, status, value) {
  res.writeHead(status, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(value);
}

function redirect(res, location, cookie) {
  const headers = { Location: location, 'Cache-Control': 'no-store' };
  if (cookie) headers['Set-Cookie'] = cookie;
  res.writeHead(303, headers);
  res.end();
}

function parseCookies(req) {
  const cookies = new Map();
  for (const item of String(req.headers.cookie || '').split(';')) {
    const separator = item.indexOf('=');
    if (separator < 1) continue;
    cookies.set(item.slice(0, separator).trim(), item.slice(separator + 1).trim());
  }
  return cookies;
}

function sessionSignature(payload) {
  return crypto.createHmac('sha256', dashboardAuth.secret).update(payload).digest('base64url');
}

function createSession(username) {
  const payload = Buffer.from(JSON.stringify({ username, expiresAt: Date.now() + SESSION_TTL_MS }))
    .toString('base64url');
  return `${payload}.${sessionSignature(payload)}`;
}

function readSession(req) {
  if (!dashboardAuth.ready) return null;
  const token = parseCookies(req).get(SESSION_COOKIE) || '';
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra) return null;
  const expected = Buffer.from(sessionSignature(payload));
  const actual = Buffer.from(signature);
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) return null;
  try {
    const value = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (!value.username || value.expiresAt < Date.now()) return null;
    return dashboardAuth.users.get(value.username) || null;
  } catch (_) {
    return null;
  }
}

function sessionCookie(token, maxAge = Math.floor(SESSION_TTL_MS / 1000)) {
  return `${SESSION_COOKIE}=${token}; Path=/; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Strict`;
}

function renderLogin(error = '') {
  const message = error ? '<p class="error" role="alert">Invalid username or password.</p>' : '';
  return LOGIN_HTML.replace('{{LOGIN_ERROR}}', message);
}

function readForm(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    let rejected = false;
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      if (rejected) return;
      body += chunk;
      if (body.length > LOGIN_BODY_LIMIT) {
        rejected = true;
        reject(new Error('request too large'));
      }
    });
    req.on('end', () => {
      if (!rejected) resolve(new URLSearchParams(body));
    });
    req.on('error', reject);
  });
}

function loginLocked(username) {
  const entry = loginFailures.get(username);
  if (!entry) return false;
  if (entry.lockedUntil > Date.now()) return true;
  if (entry.lockedUntil) loginFailures.delete(username);
  return false;
}

function recordLoginFailure(username) {
  const previous = loginFailures.get(username) || { count: 0, lockedUntil: 0 };
  const count = previous.count + 1;
  loginFailures.set(username, {
    count,
    lockedUntil: count >= LOGIN_FAILURE_LIMIT ? Date.now() + LOGIN_LOCK_MS : 0,
  });
}

function verifyPassword(user, password) {
  if (!user || typeof password !== 'string' || password.length < 1 || password.length > 128) return false;
  try {
    const actual = crypto.scryptSync(password, Buffer.from(user.salt, 'base64url'), 32);
    const expected = Buffer.from(user.hash, 'base64url');
    return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
  } catch (_) {
    return false;
  }
}

function cleanText(value, limit = 600) {
  return String(value ?? '')
    .replace(/\u001b\[[0-9;]*[A-Za-z]/g, '')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '')
    .replace(/[\t ]+/g, ' ')
    .trim()
    .slice(0, limit);
}

function gitLabConfig() {
  const apiUrl = process.env.GITLAB_API_URL?.replace(/\/$/, '');
  const projectId = process.env.GITLAB_PROJECT_ID;
  const token = process.env.GITLAB_API_TOKEN;
  if (!apiUrl || !projectId || !token) {
    throw new Error('GitLab dashboard integration is not configured');
  }
  return { apiUrl, projectId: encodeURIComponent(projectId), token };
}

async function gitLabGet(apiPath, responseType = 'json') {
  const { apiUrl, token } = gitLabConfig();
  const response = await fetch(`${apiUrl}${apiPath}`, {
    headers: { 'PRIVATE-TOKEN': token },
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`GitLab API returned ${response.status}`);
  return responseType === 'text' ? response.text() : response.json();
}

function latestJobs(jobs) {
  const result = new Map();
  [...jobs].sort((a, b) => b.id - a.id).forEach((job) => {
    if (!result.has(job.name)) result.set(job.name, job);
  });
  return [...result.values()].sort((a, b) => a.id - b.id);
}

function publicJob(job) {
  return {
    id: job.id,
    name: job.name,
    stage: job.stage,
    status: job.status,
    duration: job.duration ?? null,
    queuedDuration: job.queued_duration ?? null,
    startedAt: job.started_at ?? null,
    finishedAt: job.finished_at ?? null,
    webUrl: job.web_url ?? null,
    failureReason: job.failure_reason ? cleanText(job.failure_reason, 120) : null,
  };
}

function pipelineRunners(jobs) {
  const runners = new Map();
  for (const job of jobs) {
    if (job.runner?.id) runners.set(job.runner.id, job.runner);
  }
  return [...runners.values()];
}

function pipelineActivity(pipeline, jobs) {
  const labels = {
    build: 'Container image build',
    test: 'Application tests',
    failure_demo: 'Failure demonstration',
    security_scan: 'Trivy security scan',
    deploy: 'Production deployment',
    notify_success: 'Success notification',
    notify_failure: 'Failure notification',
  };
  const entries = jobs.map((job) => ({
    id: `job-${job.id}`,
    status: job.status,
    time: job.finished_at ?? job.started_at ?? job.created_at,
    message: `${labels[job.name] ?? job.name}: ${job.status}`,
    webUrl: job.web_url ?? null,
  }));
  entries.push({
    id: `pipeline-${pipeline.id}`,
    status: pipeline.status,
    time: pipeline.created_at,
    message: `Pipeline #${pipeline.iid} started`,
    webUrl: pipeline.web_url ?? null,
  });
  return entries
    .filter((item) => item.time)
    .sort((a, b) => new Date(b.time) - new Date(a.time))
    .slice(0, 8);
}

async function vulnerabilitySummary(securityJob) {
  const empty = {
    status: securityJob?.status ?? 'created',
    counts: { critical: null, high: null, medium: null, low: null },
    scannedAt: securityJob?.finished_at ?? securityJob?.started_at ?? null,
    reportAvailable: false,
  };
  if (!securityJob || !TERMINAL_STATUSES.has(securityJob.status)) return empty;

  try {
    const raw = await gitLabGet(
      `/projects/${gitLabConfig().projectId}/jobs/${securityJob.id}/artifacts/trivy-report.json`,
      'text',
    );
    const report = JSON.parse(raw);
    const counts = { critical: 0, high: 0, medium: 0, low: 0 };
    for (const result of report.Results ?? []) {
      for (const vulnerability of result.Vulnerabilities ?? []) {
        const severity = String(vulnerability.Severity ?? '').toLowerCase();
        if (Object.hasOwn(counts, severity)) counts[severity] += 1;
      }
    }
    return { ...empty, counts, reportAvailable: true };
  } catch (_) {
    // Older pipelines have no JSON artifact. A successful gate still proves
    // that no unfixed HIGH or CRITICAL vulnerability was found.
    if (securityJob.status === 'success') {
      return { ...empty, counts: { ...empty.counts, critical: 0, high: 0 } };
    }
    return empty;
  }
}

function extractAnalysisSection(value, heading, nextHeadings) {
  const normalized = value.replace(/\*\*/g, '');
  const next = nextHeadings.join('|').replace(/ /g, '\\s+');
  const expression = new RegExp(
    `${heading.replace(/ /g, '\\s+')}\\s*:?\\s*([\\s\\S]*?)(?=\\n\\s*(?:${next})\\s*:?|$)`,
    'i',
  );
  return cleanText(normalized.match(expression)?.[1], 700);
}

async function pipelineAnalysis(pipeline, jobs) {
  if (['running', 'pending', 'created', 'preparing', 'waiting_for_resource'].includes(pipeline.status)) {
    return {
      source: 'live',
      cause: 'Pipeline checks are still running.',
      evidence: 'Job states on this dashboard update automatically.',
      suggestedFix: 'No action is required while the pipeline is in progress.',
    };
  }
  if (pipeline.status === 'success') {
    return {
      source: 'gitlab',
      cause: 'No issues detected in this pipeline.',
      evidence: 'Build, tests, security scan, deployment, and notification completed successfully.',
      suggestedFix: 'No action required.',
    };
  }

  const notifyJob = jobs.find((job) => job.name === 'notify_failure' && job.status === 'success');
  if (notifyJob) {
    try {
      const summary = await gitLabGet(
        `/projects/${gitLabConfig().projectId}/jobs/${notifyJob.id}/artifacts/pipeline-summary.txt`,
        'text',
      );
      const cause = extractAnalysisSection(summary, 'Cause', ['Evidence', 'Suggested fix', 'Project']);
      const evidence = extractAnalysisSection(summary, 'Evidence', ['Suggested fix', 'Project']);
      const suggestedFix = extractAnalysisSection(summary, 'Suggested fix', ['Project', 'Branch', 'Commit']);
      if (cause || evidence || suggestedFix) {
        return {
          source: 'openrouter',
          cause: cause || 'The pipeline failed.',
          evidence: evidence || 'See the failed job status in the pipeline stages.',
          suggestedFix: suggestedFix || 'Review the failed job and retry after correcting the issue.',
        };
      }
    } catch (_) {
      // Fall through to a safe GitLab-only summary.
    }
  }

  const failedJob = jobs.find((job) => job.status === 'failed');
  return {
    source: 'gitlab',
    cause: failedJob ? `${failedJob.name} failed.` : `Pipeline status is ${pipeline.status}.`,
    evidence: failedJob?.failure_reason
      ? `GitLab failure reason: ${cleanText(failedJob.failure_reason, 180)}.`
      : 'GitLab marked at least one pipeline check as unsuccessful.',
    suggestedFix: failedJob
      ? `Review the ${failedJob.name} job, correct the reported error, then push a new commit.`
      : 'Review the pipeline jobs and retry after correcting the first unsuccessful stage.',
  };
}

async function loadDashboard() {
  const { projectId } = gitLabConfig();
  const project = await gitLabGet(`/projects/${projectId}`);
  const branch = encodeURIComponent(project.default_branch || 'main');
  const pipelines = await gitLabGet(
    `/projects/${projectId}/pipelines?ref=${branch}&order_by=id&sort=desc&per_page=8`,
  );
  if (!pipelines.length) throw new Error('No GitLab pipelines were returned');

  const latestPipeline = pipelines[0];
  const [pipeline, rawJobs] = await Promise.all([
    gitLabGet(`/projects/${projectId}/pipelines/${latestPipeline.id}`),
    gitLabGet(`/projects/${projectId}/pipelines/${latestPipeline.id}/jobs?include_retried=false&per_page=100`),
  ]);
  const jobs = latestJobs(rawJobs);
  // Reporter tokens cannot call the project runners endpoint. GitLab includes
  // the runner's public status on each job, which is enough for this dashboard.
  const runners = pipelineRunners(jobs);
  const securityJob = jobs.find((job) => job.name === 'security_scan');
  const deployJob = jobs.find((job) => job.name === 'deploy');
  const [security, analysis] = await Promise.all([
    vulnerabilitySummary(securityJob),
    pipelineAnalysis(pipeline, jobs),
  ]);
  const onlineRunners = runners.filter(
    (runner) => runner.online === true || runner.status === 'online',
  ).length;
  const completedJobs = jobs.filter((job) => job.status === 'success' || job.status === 'skipped').length;

  return {
    generatedAt: new Date().toISOString(),
    project: {
      name: project.name,
      path: project.path_with_namespace,
      defaultBranch: project.default_branch,
      webUrl: project.web_url,
    },
    system: {
      status: pipeline.status === 'success' && onlineRunners > 0 ? 'operational' : 'attention',
      services: { healthy: onlineRunners > 0 ? 3 : 2, total: 3 },
      runners: { online: onlineRunners, total: runners.length },
    },
    pipeline: {
      id: pipeline.id,
      iid: pipeline.iid,
      status: pipeline.status,
      ref: pipeline.ref,
      sha: pipeline.sha,
      webUrl: pipeline.web_url,
      createdAt: pipeline.created_at,
      updatedAt: pipeline.updated_at,
      duration: pipeline.duration ?? null,
      completedJobs,
      totalJobs: jobs.length,
      jobs: jobs.map(publicJob),
    },
    security,
    deployment: {
      status: deployJob?.status ?? 'created',
      finishedAt: deployJob?.finished_at ?? null,
      webUrl: deployJob?.web_url ?? null,
    },
    analysis,
    activity: pipelineActivity(pipeline, jobs),
    recentPipelines: pipelines.map((item) => ({
      id: item.id,
      iid: item.iid,
      status: item.status,
      ref: item.ref,
      sha: item.sha,
      createdAt: item.created_at,
      updatedAt: item.updated_at,
      webUrl: item.web_url,
    })),
  };
}

async function dashboardData() {
  const now = Date.now();
  if (dashboardCache.value && dashboardCache.expiresAt > now) return dashboardCache.value;
  if (dashboardCache.pending) return dashboardCache.pending;
  dashboardCache.pending = loadDashboard()
    .then((value) => {
      dashboardCache = { value, expiresAt: Date.now() + DASHBOARD_CACHE_MS, pending: null };
      return value;
    })
    .catch((error) => {
      dashboardCache.pending = null;
      throw error;
    });
  return dashboardCache.pending;
}

const server = http.createServer(async (req, res) => {
  const requestUrl = new URL(req.url, 'http://foxflow.local');

  if (req.method === 'GET' && requestUrl.pathname === '/login') {
    if (readSession(req)) {
      redirect(res, '/dashboard');
      return;
    }
    sendHtml(res, dashboardAuth.ready ? 200 : 503, renderLogin());
    return;
  }

  if (req.method === 'POST' && requestUrl.pathname === '/login') {
    if (!dashboardAuth.ready) {
      sendHtml(res, 503, renderLogin('unavailable'));
      return;
    }
    try {
      const form = await readForm(req);
      const username = String(form.get('username') || '').trim().toLowerCase();
      const password = String(form.get('password') || '');
      const user = dashboardAuth.users.get(username);
      const failureKey = user ? username : '__unknown__';
      if (loginLocked(failureKey) || !verifyPassword(user, password)) {
        recordLoginFailure(failureKey);
        sendHtml(res, 401, renderLogin('invalid'));
        return;
      }
      loginFailures.delete(failureKey);
      redirect(res, '/dashboard', sessionCookie(createSession(username)));
    } catch (_) {
      sendHtml(res, 400, renderLogin('invalid'));
    }
    return;
  }

  if (req.method === 'POST' && requestUrl.pathname === '/logout') {
    redirect(res, '/login', sessionCookie('', 0));
    return;
  }

  if (req.method !== 'GET') {
    sendJson(res, 405, { error: 'method not allowed' });
    return;
  }

  if (requestUrl.pathname === '/health') {
    if (process.env.FOXFLOW_DEMO_FAIL === 'true') {
      sendJson(res, 503, { status: 'error', service: 'foxflow-sample', demo: true });
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(HEALTH_BODY);
    return;
  }

  if (requestUrl.pathname === '/' || requestUrl.pathname === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(INDEX_HTML);
    return;
  }

  const sessionUser = readSession(req);

  if (requestUrl.pathname === '/api/session') {
    if (!sessionUser) {
      sendJson(res, 401, { error: 'authentication required' });
      return;
    }
    sendJson(res, 200, { username: sessionUser.username, name: sessionUser.name });
    return;
  }

  if (requestUrl.pathname === '/api/dashboard') {
    if (!sessionUser) {
      sendJson(res, 401, { error: 'authentication required' });
      return;
    }
    try {
      sendJson(res, 200, await dashboardData());
    } catch (error) {
      console.error(`Dashboard refresh failed: ${cleanText(error.message, 160)}`);
      sendJson(res, 503, {
        status: 'unavailable',
        message: 'Live GitLab data is temporarily unavailable.',
        generatedAt: new Date().toISOString(),
      });
    }
    return;
  }

  if (requestUrl.pathname === '/dashboard' || requestUrl.pathname === '/dashboard/') {
    if (!sessionUser) {
      redirect(res, '/login');
      return;
    }
    sendHtml(res, 200, DASHBOARD_HTML);
    return;
  }

  sendJson(res, 404, { error: 'not found' });
});

server.listen(PORT, () => {
  console.log(`FoxFlow sample app listening on port ${server.address().port}`);
});

module.exports = server;
