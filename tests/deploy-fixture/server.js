// Disposable deployment fixture, not the team's application.
const http = require('node:http');
http.createServer((req, res) => {
  if (req.url !== '/health') { res.writeHead(404); res.end(); return; }
  const mode = process.env.HEALTH_MODE || 'healthy';
  res.writeHead(mode === 'http-error' ? 503 : 200, {'Content-Type': 'application/json'});
  res.end(mode === 'invalid-json' ? 'not json' : JSON.stringify({status: 'ok', fixture: true}));
}).listen(3000, '0.0.0.0');
