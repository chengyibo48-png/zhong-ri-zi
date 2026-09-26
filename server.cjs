'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const development = process.argv.includes('--dev');
const port = Number(process.env.PORT || 4173);
http.createServer((req, res) => {
  let name;
  try { name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch (_) { res.writeHead(400);res.end();return; }
  const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403);res.end();return; }
  fs.readFile(file, (error, body) => {
    if (error) { res.writeHead(404);res.end('Not found');return; }
    res.writeHead(200, { 'Content-Type': ({ '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.json':'application/json; charset=utf-8', '.png':'image/png' })[path.extname(file)] || 'text/plain; charset=utf-8', 'Cache-Control':'no-store' });
    if(development&&path.basename(file)==='index.html')body=Buffer.from(body.toString('utf8').replace('<script src="src/data.js">','<script>window.ZRZ_DEV=true</script><script src="src/data.js">').replace('</body>','<script src="src/debug.js"></script></body>'));
    res.end(body);
  });
}).listen(port, '127.0.0.1', () => console.log('种日子已启动：http://127.0.0.1:' + port));
