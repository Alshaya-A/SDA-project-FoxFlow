// FoxFlow sample app — a minimal HTTP server using Node built-in modules only (no external dependencies)
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');

// Load the page once at startup instead of reading it on every request
const INDEX_HTML = fs.readFileSync(path.join(PUBLIC_DIR, 'index.html'));

// The exact health payload agreed in the shared contract — do not change a single character
const HEALTH_BODY = JSON.stringify({ status: 'ok', service: 'foxflow-sample' });

const server = http.createServer((req, res) => {
  // Accept GET only — reject any other method cleanly
  if (req.method !== 'GET') {
    res.writeHead(405, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'method not allowed' }));
    return;
  }

  // Health check — the pipeline relies on this exact response in normal mode.
  // The opt-in failure mode is used only by the isolated committee demo.
  if (req.url === '/health') {
    if (process.env.FOXFLOW_DEMO_FAIL === 'true') {
      res.writeHead(503, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ status: 'error', service: 'foxflow-sample', demo: true }));
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(HEALTH_BODY);
    return;
  }

  // Home page
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(INDEX_HTML);
    return;
  }

  // Any unknown path → clean 404 without leaking details
  res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, () => {
  console.log(`FoxFlow sample app listening on port ${server.address().port}`);
});

// Export the server so tests can control it
module.exports = server;
