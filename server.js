import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { handleWhatsAppApiRequest } from './whatsapp-backend.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Native zero-dependency .env loader
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    try {
      const content = fs.readFileSync(envPath, 'utf8');
      content.split(/\r?\n/).forEach(line => {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) return;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          const key = trimmed.slice(0, eqIdx).trim();
          let val = trimmed.slice(eqIdx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.slice(1, -1);
          }
          if (!process.env[key]) {
            process.env[key] = val;
          }
        }
      });
    } catch (e) {
      console.warn('[Server] Could not load .env file:', e.message);
    }
  }
}
loadEnv();

const PORT = parseInt(process.env.PORT || process.argv[2] || '8000', 10);
const HOST = 'localhost';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.jfif': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.csv': 'text/csv; charset=utf-8',
  '.pdf': 'application/pdf',
};

let latestTimestamp = Date.now();

// Watch directory for file changes to trigger live auto-reload
try {
  fs.watch(__dirname, { recursive: true }, (eventType, filename) => {
    if (filename && !filename.includes('.git') && !filename.includes('.system_generated') && !filename.includes('data')) {
      latestTimestamp = Date.now();
    }
  });
} catch (e) {
  // Fallback if recursive watch is unsupported
}

const server = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  let pathname = decodeURIComponent(parsedUrl.pathname);

  // WhatsApp Backend API Router
  if (pathname.startsWith('/api/whatsapp')) {
    handleWhatsAppApiRequest(req, res, parsedUrl);
    return;
  }

  // Safe Client Environment Configuration Endpoint
  if (pathname === '/api/config') {
    const clientConfig = {
      supabase_url: process.env.SUPABASE_URL || '',
      supabase_anon_key: process.env.SUPABASE_ANON_KEY || '',
      meta_phone_number: process.env.META_PHONE_NUMBER || '+91 86591 63665',
      google_calendar_id: process.env.GOOGLE_CALENDAR_ID || 'goldenkids.academic@gmail.com',
      has_whatsapp_token: Boolean(process.env.META_WHATSAPP_TOKEN),
      has_supabase_service_role: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY)
    };
    const json = JSON.stringify(clientConfig);
    res.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': Buffer.byteLength(json),
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(json);
    return;
  }

  // Live Server auto-reload heartbeat endpoint (matching index.html client script)
  if (pathname === '/__livereload') {
    const json = JSON.stringify({ timestamp: latestTimestamp });
    res.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': Buffer.byteLength(json),
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(json);
    return;
  }

  if (pathname === '/' || pathname === '') {
    pathname = '/index.html';
  }

  const safePath = path.normalize(pathname).replace(/^(\.\.[/\\])+/, '');
  let filePath = path.join(__dirname, safePath);

  // Check if target is a directory or doesn't exist (SPA fallback to index.html)
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(__dirname, 'index.html');
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': data.length,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(data);
  });
});

server.listen(PORT, HOST, () => {
  console.log('\n==========================================================');
  console.log('   Golden Kids School - Local LIVE Web Server');
  console.log(`   Live URL: http://${HOST}:${PORT}/`);
  console.log(`   Serving:  ${__dirname}`);
  console.log('   Features: Auto-Reload on Save, .jfif MIME, SPA Fallback');
  console.log('   Press Ctrl+C in this console to stop the server');
  console.log('==========================================================\n');
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    const nextPort = PORT + 1;
    console.log(`Port ${PORT} is in use, trying port ${nextPort}...`);
    server.listen(nextPort, HOST);
  } else {
    console.error('Server error:', err);
  }
});
