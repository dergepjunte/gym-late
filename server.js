'use strict';

const express = require('express');
const crypto  = require('crypto');
const path    = require('path');
const zlib    = require('zlib');

// ── PWA Icon Generator (pure Node.js, no dependencies) ──────────────────────
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
    row[0] = 0;
    for (let x = 0; x < size; x++) {
      const t = (x / (size - 1) + y / (size - 1)) / 2;
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

const app = express();
const PORT = process.env.PORT || 3000;
const ADMIN_PW = process.env.ADMIN_PW || 'gymadmin';
const USE_MYSQL = Boolean(process.env.MYSQL_URL);
let database;

function isUniqueError(e) {
  return e?.code === 'SQLITE_CONSTRAINT_UNIQUE' || e?.code === 'ER_DUP_ENTRY';
}

function insertIgnore() {
  return database.isMySQL ? 'INSERT IGNORE' : 'INSERT OR IGNORE';
}

function createSqliteDatabase() {
  const Database = require('better-sqlite3');
  const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'data.db');
  const sqlite = new Database(DB_PATH);
  sqlite.pragma('journal_mode = WAL');
  sqlite.pragma('foreign_keys = ON');
  console.log(`📂 SQLite database: ${DB_PATH}`);

  return {
    isMySQL: false,
    exec(sql) { sqlite.exec(sql); },
    async run(sql, params = []) { return sqlite.prepare(sql).run(...params); },
    async one(sql, params = []) { return sqlite.prepare(sql).get(...params) || null; },
    async all(sql, params = []) { return sqlite.prepare(sql).all(...params); },
    async transaction(fn) {
      const wrapped = sqlite.transaction(() => fn(this));
      return wrapped();
    },
  };
}

async function createMysqlDatabase() {
  const mysql = require('mysql2/promise');
  const pool = mysql.createPool(process.env.MYSQL_URL);
  console.log('📂 MySQL database: MYSQL_URL');

  const clientFrom = (conn) => ({
    isMySQL: true,
    async run(sql, params = []) { const [r] = await conn.execute(sql, params); return r; },
    async one(sql, params = []) { const [rows] = await conn.execute(sql, params); return rows[0] || null; },
    async all(sql, params = []) { const [rows] = await conn.execute(sql, params); return rows; },
  });

  return {
    isMySQL: true,
    async run(sql, params = []) { const [r] = await pool.execute(sql, params); return r; },
    async one(sql, params = []) { const [rows] = await pool.execute(sql, params); return rows[0] || null; },
    async all(sql, params = []) { const [rows] = await pool.execute(sql, params); return rows; },
    async transaction(fn) {
      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();
        const result = await fn(clientFrom(conn));
        await conn.commit();
        return result;
      } catch (e) {
        await conn.rollback();
        throw e;
      } finally {
        conn.release();
      }
    },
  };
}

async function initSchema() {
  if (database.isMySQL) {
    await database.run(`
      CREATE TABLE IF NOT EXISTS \`groups\` (
        id VARCHAR(36) PRIMARY KEY,
        code VARCHAR(6) UNIQUE NOT NULL,
        name VARCHAR(50) NOT NULL,
        created_at BIGINT NOT NULL,
        creator_user_id VARCHAR(36) NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    await database.run(`
      CREATE TABLE IF NOT EXISTS members (
        id VARCHAR(36) PRIMARY KEY,
        group_id VARCHAR(36) NOT NULL,
        name VARCHAR(30) NOT NULL,
        created_at BIGINT NOT NULL,
        UNIQUE KEY uniq_members_group_name (group_id, name),
        INDEX idx_members_group_id (group_id),
        CONSTRAINT fk_members_group FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    await database.run(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        group_id VARCHAR(36) NOT NULL,
        name VARCHAR(30) NOT NULL,
        recovery_code VARCHAR(14) NOT NULL,
        avatar_emoji VARCHAR(16) NOT NULL DEFAULT '🏋️',
        avatar_color VARCHAR(16) NOT NULL DEFAULT '#7c3aed',
        is_creator TINYINT NOT NULL DEFAULT 0,
        created_at BIGINT NOT NULL,
        UNIQUE KEY uniq_users_group_name (group_id, name),
        INDEX idx_users_group_id (group_id),
        CONSTRAINT fk_users_group FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    await database.run(`
      CREATE TABLE IF NOT EXISTS entries (
        id VARCHAR(36) PRIMARY KEY,
        group_id VARCHAR(36) NOT NULL,
        person VARCHAR(30) NOT NULL,
        date CHAR(10) NOT NULL,
        mins INT NOT NULL,
        ts BIGINT NOT NULL,
        INDEX idx_entries_group_id (group_id),
        CONSTRAINT fk_entries_group FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    try { await database.run('ALTER TABLE `groups` ADD COLUMN creator_user_id VARCHAR(36) NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    return;
  }

  database.exec(`
    CREATE TABLE IF NOT EXISTS \`groups\` (
      id         TEXT PRIMARY KEY,
      code       TEXT UNIQUE NOT NULL,
      name       TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      creator_user_id TEXT
    );

    CREATE TABLE IF NOT EXISTS members (
      id         TEXT PRIMARY KEY,
      group_id   TEXT NOT NULL REFERENCES \`groups\`(id) ON DELETE CASCADE,
      name       TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(group_id, name COLLATE NOCASE)
    );

    CREATE TABLE IF NOT EXISTS users (
      id            TEXT PRIMARY KEY,
      group_id      TEXT NOT NULL REFERENCES \`groups\`(id) ON DELETE CASCADE,
      name          TEXT NOT NULL,
      recovery_code TEXT NOT NULL,
      avatar_emoji  TEXT NOT NULL DEFAULT '🏋️',
      avatar_color  TEXT NOT NULL DEFAULT '#7c3aed',
      is_creator    INTEGER NOT NULL DEFAULT 0,
      created_at    INTEGER NOT NULL,
      UNIQUE(group_id, name COLLATE NOCASE)
    );

    CREATE TABLE IF NOT EXISTS entries (
      id         TEXT PRIMARY KEY,
      group_id   TEXT NOT NULL REFERENCES \`groups\`(id) ON DELETE CASCADE,
      person     TEXT NOT NULL,
      date       TEXT NOT NULL,
      mins       INTEGER NOT NULL,
      ts         INTEGER NOT NULL
    );
  `);
  try { database.exec('ALTER TABLE `groups` ADD COLUMN creator_user_id TEXT'); } catch {}
}

// ── Code generators ──────────────────────────────────────────────────────────
const ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function genCode() {
  const bytes = crypto.randomBytes(6);
  return Array.from(bytes, b => ALPHA[b % ALPHA.length]).join('');
}

function genRecoveryCode() {
  return [0, 1, 2].map(() =>
    Array.from(crypto.randomBytes(4), b => ALPHA[b % ALPHA.length]).join('')
  ).join('-');
}

async function uniqueCode(client = database) {
  let code;
  do {
    code = genCode();
  } while (await client.one('SELECT 1 AS found FROM `groups` WHERE code = ?', [code]));
  return code;
}

function dateYMD(d) {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

function addDaysUTC(d, days) {
  const copy = new Date(d);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function currentMondayUTC() {
  const d = new Date();
  d.setUTCHours(12, 0, 0, 0);
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() - day + 1);
  return d;
}

async function startupMigration() {
  const unmigrated = await database.all(`
    SELECT m.id, m.group_id, m.name, m.created_at
    FROM members m
    LEFT JOIN users u ON u.group_id = m.group_id AND LOWER(u.name) = LOWER(m.name)
    WHERE u.id IS NULL
  `);

  for (const m of unmigrated) {
    await database.run(`
      ${insertIgnore()} INTO users (id, group_id, name, recovery_code, avatar_emoji, avatar_color, is_creator, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 0, ?)
    `, [m.id, m.group_id, m.name, genRecoveryCode(), '🏋️', '#7c3aed', m.created_at]);
  }

  const groupsNoCreator = await database.all(`
    SELECT g.id FROM \`groups\` g
    WHERE g.creator_user_id IS NULL
    AND EXISTS (SELECT 1 FROM users u WHERE u.group_id = g.id)
  `);

  for (const g of groupsNoCreator) {
    const first = await database.one('SELECT id FROM users WHERE group_id = ? ORDER BY created_at LIMIT 1', [g.id]);
    if (first) {
      await database.run('UPDATE `groups` SET creator_user_id = ? WHERE id = ? AND creator_user_id IS NULL', [first.id, g.id]);
      await database.run('UPDATE users SET is_creator = 1 WHERE id = ?', [first.id]);
    }
  }
}

function userDto(u) {
  return {
    id: u.id,
    name: u.name,
    avatarEmoji: u.avatar_emoji,
    avatarColor: u.avatar_color,
    isCreator: Number(u.is_creator) === 1,
  };
}

const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '16kb' }));

// ── PWA Icon routes ──────────────────────────────────────────────────────────
const iconHeaders = (res) => {
  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Cache-Control', 'public, max-age=86400');
};
app.get('/apple-touch-icon.png',         (_, res) => { iconHeaders(res); res.send(getIcon(180)); });
app.get('/apple-touch-icon-180x180.png', (_, res) => { iconHeaders(res); res.send(getIcon(180)); });
app.get('/icon-192.png',                 (_, res) => { iconHeaders(res); res.send(getIcon(192)); });
app.get('/icon-512.png',                 (_, res) => { iconHeaders(res); res.send(getIcon(512)); });

// ── Groups ───────────────────────────────────────────────────────────────────

app.post('/api/groups', ah(async (req, res) => {
  const name = String(req.body?.name ?? '').trim().slice(0, 50);
  if (!name) return res.status(400).json({ error: 'name_required' });
  const id = crypto.randomUUID();
  const code = await uniqueCode();
  await database.run('INSERT INTO `groups` (id,code,name,created_at) VALUES (?,?,?,?)', [id, code, name, Date.now()]);
  res.json({ id, code, name });
}));

app.post('/api/test-group', ah(async (req, res) => {
  const password = String(req.body?.password ?? '').trim().toLowerCase();
  if (password !== ADMIN_PW.toLowerCase()) return res.status(401).json({ error: 'unauthorized' });

  const demo = await database.transaction(async (tx) => {
    const now = Date.now();
    const groupId = crypto.randomUUID();
    const code = await uniqueCode(tx);
    const groupName = 'GymLate Demo';
    const people = [
      { name: 'Alex', avatarEmoji: '💪', avatarColor: '#7c3aed' },
      { name: 'Mia',  avatarEmoji: '🔥', avatarColor: '#db2777' },
      { name: 'Noah', avatarEmoji: '⚡', avatarColor: '#ea580c' },
      { name: 'Lina', avatarEmoji: '🎯', avatarColor: '#16a34a' },
    ];

    await tx.run('INSERT INTO `groups` (id,code,name,created_at) VALUES (?,?,?,?)', [groupId, code, groupName, now]);

    const createdUsers = [];
    for (const [index, person] of people.entries()) {
      const userId = crypto.randomUUID();
      const recoveryCode = genRecoveryCode();
      const createdAt = now + index;
      const isCreator = index === 0 ? 1 : 0;
      await tx.run(`
        INSERT INTO users (id, group_id, name, recovery_code, avatar_emoji, avatar_color, is_creator, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [userId, groupId, person.name, recoveryCode, person.avatarEmoji, person.avatarColor, isCreator, createdAt]);
      await tx.run('INSERT INTO members (id,group_id,name,created_at) VALUES (?,?,?,?)', [userId, groupId, person.name, createdAt]);
      if (isCreator) {
        await tx.run('UPDATE `groups` SET creator_user_id = ? WHERE id = ?', [userId, groupId]);
      }
      createdUsers.push({ userId, recoveryCode, isCreator: isCreator === 1, ...person });
    }

    const entryIds = [];
    const currentMon = currentMondayUTC();
    for (let weeksAgo = 52; weeksAgo >= 1; weeksAgo--) {
      const mon = addDaysUTC(currentMon, -7 * weeksAgo);
      const entriesThisWeek = 4 + (weeksAgo % 5);
      for (let i = 0; i < entriesThisWeek; i++) {
        const person = people[(weeksAgo + i * 2) % people.length].name;
        const date = dateYMD(addDaysUTC(mon, i % 5));
        const mins = 5 + ((weeksAgo * 7 + i * 11) % 41);
        const entryId = crypto.randomUUID();
        entryIds.push(entryId);
        await tx.run('INSERT INTO entries (id,group_id,person,date,mins,ts) VALUES (?,?,?,?,?,?)',
          [entryId, groupId, person, date, mins, now + weeksAgo * 100 + i]);
      }
    }

    const creator = createdUsers[0];
    return {
      group: { id: groupId, code, name: groupName },
      user: {
        userId: creator.userId,
        name: creator.name,
        avatarEmoji: creator.avatarEmoji,
        avatarColor: creator.avatarColor,
        recoveryCode: creator.recoveryCode,
        isCreator: true,
      },
      entryIds,
    };
  });

  res.json(demo);
}));

app.post('/api/groups/join', ah(async (req, res) => {
  const code = String(req.body?.code ?? '').toUpperCase().trim();
  if (!code) return res.status(400).json({ error: 'code_required' });
  const g = await database.one('SELECT id,code,name FROM `groups` WHERE code = ?', [code]);
  if (!g) return res.status(404).json({ error: 'not_found' });
  res.json(g);
}));

app.get('/api/groups/:id', ah(async (req, res) => {
  const g = await database.one('SELECT id,code,name,creator_user_id FROM `groups` WHERE id = ?', [req.params.id]);
  if (!g) return res.status(404).json({ error: 'not_found' });
  const people = (await database.all(`
    SELECT id, name, avatar_emoji, avatar_color, is_creator
    FROM users WHERE group_id = ? ORDER BY created_at
  `, [req.params.id])).map(userDto);
  const entries = await database.all('SELECT id,person,date,mins,ts FROM entries WHERE group_id = ? ORDER BY date DESC, ts DESC', [req.params.id]);
  res.json({ id: g.id, code: g.code, name: g.name, people, entries });
}));

// ── Users ────────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/users', ah(async (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim().slice(0, 30);
  const avatarEmoji = String(req.body?.avatarEmoji ?? '🏋️');
  const avatarColor = String(req.body?.avatarColor ?? '#7c3aed');

  if (!name) return res.status(400).json({ error: 'name_required' });
  const g = await database.one('SELECT id, creator_user_id FROM `groups` WHERE id = ?', [id]);
  if (!g) return res.status(404).json({ error: 'not_found' });

  const userId = crypto.randomUUID();
  const recoveryCode = genRecoveryCode();
  const isCreator = g.creator_user_id === null ? 1 : 0;
  const now = Date.now();

  try {
    await database.run(`
      INSERT INTO users (id, group_id, name, recovery_code, avatar_emoji, avatar_color, is_creator, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [userId, id, name, recoveryCode, avatarEmoji, avatarColor, isCreator, now]);

    await database.run(`${insertIgnore()} INTO members (id, group_id, name, created_at) VALUES (?,?,?,?)`, [userId, id, name, now]);

    if (isCreator) {
      await database.run('UPDATE `groups` SET creator_user_id = ? WHERE id = ? AND creator_user_id IS NULL', [userId, id]);
    }

    res.json({ userId, name, avatarEmoji, avatarColor, recoveryCode, isCreator: isCreator === 1 });
  } catch (e) {
    if (isUniqueError(e)) return res.status(409).json({ error: 'already_exists' });
    throw e;
  }
}));

app.post('/api/groups/:id/users/login', ah(async (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim();
  const recoveryCode = String(req.body?.recoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();

  if (!name || !recoveryCode) return res.status(400).json({ error: 'missing_fields' });

  const user = await database.one(`
    SELECT id, name, avatar_emoji, avatar_color, is_creator, recovery_code
    FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)
  `, [id, name]);

  if (!user) return res.status(404).json({ error: 'user_not_found' });
  if (user.recovery_code.replace(/-/g, '') !== recoveryCode) return res.status(401).json({ error: 'wrong_code' });

  res.json({
    userId: user.id,
    name: user.name,
    avatarEmoji: user.avatar_emoji,
    avatarColor: user.avatar_color,
    isCreator: Number(user.is_creator) === 1,
  });
}));

app.patch('/api/groups/:id/users/:uid', ah(async (req, res) => {
  const { id, uid } = req.params;
  const recoveryCode = String(req.body?.recoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();

  const user = await database.one('SELECT id, recovery_code, name FROM users WHERE id = ? AND group_id = ?', [uid, id]);
  if (!user) return res.status(404).json({ error: 'not_found' });
  if (user.recovery_code.replace(/-/g, '') !== recoveryCode) return res.status(401).json({ error: 'unauthorized' });

  const newName = req.body?.name ? String(req.body.name).trim().slice(0, 30) : null;
  const newEmoji = req.body?.avatarEmoji ? String(req.body.avatarEmoji) : null;
  const newColor = req.body?.avatarColor ? String(req.body.avatarColor) : null;

  const sets = [];
  const params = [];
  if (newName) { sets.push('name = ?'); params.push(newName); }
  if (newEmoji) { sets.push('avatar_emoji = ?'); params.push(newEmoji); }
  if (newColor) { sets.push('avatar_color = ?'); params.push(newColor); }
  if (!sets.length) return res.json({ ok: true });

  params.push(uid, id);
  try {
    await database.run(`UPDATE users SET ${sets.join(', ')} WHERE id = ? AND group_id = ?`, params);
    if (newName && newName !== user.name) {
      await database.run('UPDATE entries SET person = ? WHERE group_id = ? AND person = ?', [newName, id, user.name]);
      await database.run('UPDATE members SET name = ? WHERE group_id = ? AND name = ?', [newName, id, user.name]);
    }
    res.json({ ok: true });
  } catch (e) {
    if (isUniqueError(e)) return res.status(409).json({ error: 'name_taken' });
    throw e;
  }
}));

app.delete('/api/groups/:id/users/:uid', ah(async (req, res) => {
  const { id, uid } = req.params;
  const actorId = String(req.body?.actorUserId ?? '');
  const actorCode = String(req.body?.actorRecoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();

  const actor = await database.one('SELECT id, recovery_code, is_creator FROM users WHERE id = ? AND group_id = ?', [actorId, id]);
  if (!actor) return res.status(401).json({ error: 'unauthorized' });
  if (actor.recovery_code.replace(/-/g, '') !== actorCode) return res.status(401).json({ error: 'unauthorized' });
  if (Number(actor.is_creator) !== 1) return res.status(403).json({ error: 'not_creator' });
  if (uid === actorId) return res.status(400).json({ error: 'cannot_kick_self' });

  const target = await database.one('SELECT id, name FROM users WHERE id = ? AND group_id = ?', [uid, id]);
  if (!target) return res.status(404).json({ error: 'not_found' });

  await database.run('DELETE FROM users WHERE id = ? AND group_id = ?', [uid, id]);
  await database.run('DELETE FROM members WHERE group_id = ? AND name = ?', [id, target.name]);

  res.json({ ok: true });
}));

// ── Members (legacy, kept for compatibility) ─────────────────────────────────

app.post('/api/groups/:id/members', ah(async (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim().slice(0, 30);
  if (!name) return res.status(400).json({ error: 'name_required' });
  if (!await database.one('SELECT 1 AS found FROM `groups` WHERE id = ?', [id])) return res.status(404).json({ error: 'not_found' });
  try {
    const uid = crypto.randomUUID();
    const now = Date.now();
    await database.run('INSERT INTO members (id,group_id,name,created_at) VALUES (?,?,?,?)', [uid, id, name, now]);
    await database.run(`${insertIgnore()} INTO users (id,group_id,name,recovery_code,avatar_emoji,avatar_color,is_creator,created_at) VALUES (?,?,?,?,?,?,0,?)`,
      [uid, id, name, genRecoveryCode(), '🏋️', '#7c3aed', now]);
    res.json({ ok: true });
  } catch (e) {
    if (isUniqueError(e)) return res.status(409).json({ error: 'already_exists' });
    throw e;
  }
}));

app.delete('/api/groups/:id/members/:name', ah(async (req, res) => {
  await database.run('DELETE FROM members WHERE group_id = ? AND name = ?', [req.params.id, req.params.name]);
  await database.run('DELETE FROM users WHERE group_id = ? AND name = ?', [req.params.id, req.params.name]);
  res.json({ ok: true });
}));

// ── Entries ──────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/entries', ah(async (req, res) => {
  const { id } = req.params;
  const person = String(req.body?.person ?? '').trim().slice(0, 30);
  const date = String(req.body?.date ?? '').trim();
  const mins = parseInt(req.body?.mins);
  if (!person || !date || isNaN(mins) || mins < 1 || mins > 999) return res.status(400).json({ error: 'invalid' });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return res.status(400).json({ error: 'invalid_date' });
  if (!await database.one('SELECT 1 AS found FROM `groups` WHERE id = ?', [id])) return res.status(404).json({ error: 'not_found' });
  const eid = crypto.randomUUID();
  await database.run('INSERT INTO entries (id,group_id,person,date,mins,ts) VALUES (?,?,?,?,?,?)', [eid, id, person, date, mins, Date.now()]);
  res.json({ ok: true, id: eid });
}));

app.delete('/api/groups/:id/entries/:eid', ah(async (req, res) => {
  await database.run('DELETE FROM entries WHERE id = ? AND group_id = ?', [req.params.eid, req.params.id]);
  res.json({ ok: true });
}));

app.use(express.static(__dirname));

app.use((err, req, res, next) => {
  console.error(err);
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'server_error' });
});

// ── Start ────────────────────────────────────────────────────────────────────
async function main() {
  database = USE_MYSQL ? await createMysqlDatabase() : createSqliteDatabase();
  await initSchema();
  await startupMigration();
  app.listen(PORT, () => {
    console.log(`\n🏋️  GymLate läuft auf http://localhost:${PORT}\n`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
