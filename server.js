'use strict';

const express  = require('express');
const Database = require('better-sqlite3');
const crypto   = require('crypto');
const path     = require('path');

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
