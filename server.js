'use strict';

const express  = require('express');
const Database = require('better-sqlite3');
const crypto   = require('crypto');
const path     = require('path');
const zlib     = require('zlib');

// ── PWA Icon Generator (pure Node.js, no dependencies) ──────────────────────
// Generates a purple-gradient PNG with a white dumbbell silhouette
function generateIconPNG(size) {
  function crc32(buf) {
    const T = (() => {
      const t = new Uint32Array(256);
      for (let i = 0; i < 256; i++) {
        let c = i;
        for (let k = 0; k < 8; k++) c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        t[i] = c;
      }
      return t;
    })();
    let crc = 0xffffffff;
    for (const b of buf) crc = T[(crc ^ b) & 0xff] ^ (crc >>> 8);
    return (crc ^ 0xffffffff) >>> 0;
  }
  function u32(n) { const b = Buffer.alloc(4); b.writeUInt32BE(n); return b; }
  function chunk(type, data) {
    const t = Buffer.from(type, 'ascii');
    const c = Buffer.concat([t, data]);
    return Buffer.concat([u32(data.length), t, data, u32(crc32(c))]);
  }

  // Dumbbell geometry
  const cx = size / 2, cy = size / 2;
  const plateR = size * 0.17;
  const armLen = size * 0.23;
  const barH   = size * 0.058;

  function inDumbbell(x, y) {
    return (
      Math.hypot(x - (cx - armLen), y - cy) < plateR ||
      Math.hypot(x - (cx + armLen), y - cy) < plateR ||
      (Math.abs(y - cy) < barH && x > cx - armLen && x < cx + armLen)
    );
  }

  const rows = [];
  for (let y = 0; y < size; y++) {
    const row = Buffer.alloc(1 + size * 3);
    row[0] = 0; // PNG filter: None
    for (let x = 0; x < size; x++) {
      const t = (x / (size - 1) + y / (size - 1)) / 2; // diagonal gradient 0→1
      // Diagonal gradient: #7c3aed → #c084fc
      const pr = Math.round(0x7c + (0xc0 - 0x7c) * t);
      const pg = Math.round(0x3a + (0x84 - 0x3a) * t);
      const pb = Math.round(0xed + (0xfc - 0xed) * t);
      const [r, g, b] = inDumbbell(x, y) ? [255, 255, 255] : [pr, pg, pb];
      row[1 + x * 3] = r; row[2 + x * 3] = g; row[3 + x * 3] = b;
    }
    rows.push(row);
  }

  const compressed = zlib.deflateSync(Buffer.concat(rows), { level: 6 });
  const sig  = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = chunk('IHDR', Buffer.concat([u32(size), u32(size), Buffer.from([8, 2, 0, 0, 0])]));
  const idat = chunk('IDAT', compressed);
  const iend = chunk('IEND', Buffer.alloc(0));
  return Buffer.concat([sig, ihdr, idat, iend]);
}

const iconCache = {};
function getIcon(size) {
  if (!iconCache[size]) iconCache[size] = generateIconPNG(size);
  return iconCache[size];
}

const app  = express();
const PORT = process.env.PORT || 3000;
const db   = new Database(path.join(__dirname, 'data.db'));

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS groups (
    id         TEXT PRIMARY KEY,
    code       TEXT UNIQUE NOT NULL,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS members (
    id         TEXT PRIMARY KEY,
    group_id   TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE(group_id, name COLLATE NOCASE)
  );

  CREATE TABLE IF NOT EXISTS entries (
    id         TEXT PRIMARY KEY,
    group_id   TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    person     TEXT NOT NULL,
    date       TEXT NOT NULL,
    mins       INTEGER NOT NULL,
    ts         INTEGER NOT NULL
  );
`);

// ── Code generator ───────────────────────────────────────────────────────────
const ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I to avoid confusion

function genCode() {
  const bytes = crypto.randomBytes(6);
  return Array.from(bytes, b => ALPHA[b % ALPHA.length]).join('');
}

function uniqueCode() {
  const exists = db.prepare('SELECT 1 FROM groups WHERE code = ?');
  let code;
  do { code = genCode(); } while (exists.get(code));
  return code;
}

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '16kb' }));

// ── PWA Icon routes ──────────────────────────────────────────────────────────
const iconHeaders = (res) => {
  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Cache-Control', 'public, max-age=86400');
};
app.get('/apple-touch-icon.png',        (_, res) => { iconHeaders(res); res.send(getIcon(180)); });
app.get('/apple-touch-icon-180x180.png',(_, res) => { iconHeaders(res); res.send(getIcon(180)); });
app.get('/icon-192.png',                (_, res) => { iconHeaders(res); res.send(getIcon(192)); });
app.get('/icon-512.png',                (_, res) => { iconHeaders(res); res.send(getIcon(512)); });

app.use(express.static(__dirname));

// ── Groups ───────────────────────────────────────────────────────────────────

app.post('/api/groups', (req, res) => {
  const name = String(req.body?.name ?? '').trim().slice(0, 50);
  if (!name) return res.status(400).json({ error: 'name_required' });
  const id   = crypto.randomUUID();
  const code = uniqueCode();
  db.prepare('INSERT INTO groups (id,code,name,created_at) VALUES (?,?,?,?)')
    .run(id, code, name, Date.now());
  res.json({ id, code, name });
});

app.post('/api/groups/join', (req, res) => {
  const code = String(req.body?.code ?? '').toUpperCase().trim();
  if (!code) return res.status(400).json({ error: 'code_required' });
  const g = db.prepare('SELECT id,code,name FROM groups WHERE code = ?').get(code);
  if (!g) return res.status(404).json({ error: 'not_found' });
  res.json(g);
});

app.get('/api/groups/:id', (req, res) => {
  const g = db.prepare('SELECT id,code,name FROM groups WHERE id = ?').get(req.params.id);
  if (!g) return res.status(404).json({ error: 'not_found' });
  const people  = db.prepare('SELECT name FROM members WHERE group_id = ? ORDER BY created_at')
                    .all(req.params.id).map(r => r.name);
  const entries = db.prepare('SELECT id,person,date,mins,ts FROM entries WHERE group_id = ? ORDER BY date DESC, ts DESC')
                    .all(req.params.id);
  res.json({ ...g, people, entries });
});

// ── Members ──────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/members', (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim().slice(0, 30);
  if (!name) return res.status(400).json({ error: 'name_required' });
  if (!db.prepare('SELECT 1 FROM groups WHERE id = ?').get(id))
    return res.status(404).json({ error: 'not_found' });
  try {
    db.prepare('INSERT INTO members (id,group_id,name,created_at) VALUES (?,?,?,?)')
      .run(crypto.randomUUID(), id, name, Date.now());
    res.json({ ok: true });
  } catch {
    res.status(409).json({ error: 'already_exists' });
  }
});

app.delete('/api/groups/:id/members/:name', (req, res) => {
  db.prepare('DELETE FROM members WHERE group_id = ? AND name = ?')
    .run(req.params.id, req.params.name);
  res.json({ ok: true });
});

// ── Entries ──────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/entries', (req, res) => {
  const { id } = req.params;
  const person = String(req.body?.person ?? '').trim().slice(0, 30);
  const date   = String(req.body?.date   ?? '').trim();
  const mins   = parseInt(req.body?.mins);
  if (!person || !date || isNaN(mins) || mins < 1 || mins > 999)
    return res.status(400).json({ error: 'invalid' });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date))
    return res.status(400).json({ error: 'invalid_date' });
  if (!db.prepare('SELECT 1 FROM groups WHERE id = ?').get(id))
    return res.status(404).json({ error: 'not_found' });
  const eid = crypto.randomUUID();
  db.prepare('INSERT INTO entries (id,group_id,person,date,mins,ts) VALUES (?,?,?,?,?,?)')
    .run(eid, id, person, date, mins, Date.now());
  res.json({ ok: true, id: eid });
});

app.delete('/api/groups/:id/entries/:eid', (req, res) => {
  db.prepare('DELETE FROM entries WHERE id = ? AND group_id = ?')
    .run(req.params.eid, req.params.id);
  res.json({ ok: true });
});

// ── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🏋️  GymLate läuft auf http://localhost:${PORT}\n`);
});
