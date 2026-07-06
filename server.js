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
const USE_MYSQL = Boolean(process.env.MYSQL_URL);
let database;

// ── Admin auth (password stored only as SHA-256 hash, never plaintext) ────────
function sha256(s) { return crypto.createHash('sha256').update(s, 'utf8').digest('hex'); }
// Default hash = sha256('gymadmin'); override by setting ADMIN_PW env var
const ADMIN_PW_HASH = process.env.ADMIN_PW
  ? sha256(process.env.ADMIN_PW)
  : 'e935e949b07bf303aaccb0ded79176a9274565a1a014b775b5fe1d2b892a778d';
function isAdmin(req) {
  const pw = String(req.body?.adminPassword ?? req.body?.password ?? '').trim();
  return pw.length > 0 && sha256(pw) === ADMIN_PW_HASH;
}

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
        creator_user_id VARCHAR(36) NULL,
        gym_days CHAR(7) NOT NULL DEFAULT '1111111',
        gym_lat DOUBLE NULL,
        gym_lng DOUBLE NULL,
        gym_radius INT NULL
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
        avail_days CHAR(7) NULL,
        avail_edited_at BIGINT NULL,
        streak INT NOT NULL DEFAULT 0,
        freezes INT NOT NULL DEFAULT 0,
        last_streak_date VARCHAR(10) NULL,
        last_freeze_grant BIGINT NULL,
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
        type VARCHAR(10) NOT NULL DEFAULT 'late',
        reason VARCHAR(20) NULL,
        INDEX idx_entries_group_id (group_id),
        CONSTRAINT fk_entries_group FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    try { await database.run('ALTER TABLE `groups` ADD COLUMN creator_user_id VARCHAR(36) NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run("ALTER TABLE `groups` ADD COLUMN gym_days CHAR(7) NOT NULL DEFAULT '1111111'"); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE `groups` ADD COLUMN gym_lat DOUBLE NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE `groups` ADD COLUMN gym_lng DOUBLE NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE `groups` ADD COLUMN gym_radius INT NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN avatar_img MEDIUMTEXT NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN avail_days CHAR(7) NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN avail_edited_at BIGINT NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN streak INT NOT NULL DEFAULT 0'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN freezes INT NOT NULL DEFAULT 0'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN last_streak_date VARCHAR(10) NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE users ADD COLUMN last_freeze_grant BIGINT NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run("ALTER TABLE entries ADD COLUMN type VARCHAR(10) NOT NULL DEFAULT 'late'"); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE entries ADD COLUMN reason VARCHAR(20) NULL'); } catch (e) {
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
      creator_user_id TEXT,
      gym_days   TEXT NOT NULL DEFAULT '1111111',
      gym_lat    REAL,
      gym_lng    REAL,
      gym_radius INTEGER
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
      avail_days    TEXT,
      avail_edited_at INTEGER,
      streak        INTEGER NOT NULL DEFAULT 0,
      freezes       INTEGER NOT NULL DEFAULT 0,
      last_streak_date TEXT,
      last_freeze_grant INTEGER,
      UNIQUE(group_id, name COLLATE NOCASE)
    );

    CREATE TABLE IF NOT EXISTS entries (
      id         TEXT PRIMARY KEY,
      group_id   TEXT NOT NULL REFERENCES \`groups\`(id) ON DELETE CASCADE,
      person     TEXT NOT NULL,
      date       TEXT NOT NULL,
      mins       INTEGER NOT NULL,
      ts         INTEGER NOT NULL,
      type       TEXT NOT NULL DEFAULT 'late',
      reason     TEXT
    );
  `);
  try { database.exec('ALTER TABLE `groups` ADD COLUMN creator_user_id TEXT'); } catch {}
  try { database.exec("ALTER TABLE `groups` ADD COLUMN gym_days TEXT NOT NULL DEFAULT '1111111'"); } catch {}
  try { database.exec('ALTER TABLE `groups` ADD COLUMN gym_lat REAL'); } catch {}
  try { database.exec('ALTER TABLE `groups` ADD COLUMN gym_lng REAL'); } catch {}
  try { database.exec('ALTER TABLE `groups` ADD COLUMN gym_radius INTEGER'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avatar_img TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avail_days TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avail_edited_at INTEGER'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN streak INTEGER NOT NULL DEFAULT 0'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN freezes INTEGER NOT NULL DEFAULT 0'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN last_streak_date TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN last_freeze_grant INTEGER'); } catch {}
  try { database.exec("ALTER TABLE entries ADD COLUMN type TEXT NOT NULL DEFAULT 'late'"); } catch {}
  try { database.exec('ALTER TABLE entries ADD COLUMN reason TEXT'); } catch {}
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

function isValidGymDays(value) {
  return typeof value === 'string' && /^[01]{7}$/.test(value);
}

const LOCK_OPEN_MS     = 60 * 60 * 1000;           // 1 h free-edit window
const LOCK_DURATION_MS = 30 * 24 * 60 * 60 * 1000; // 30 d lock
const PITY_MS          = 7  * 24 * 60 * 60 * 1000; // freeze pity resets weekly
const MAX_LOOKBACK     = 90;                         // days of streak history to scan

function effectiveMask(gymDays, availDays) {
  const gd = gymDays || '0000000'; // no gym days = never miss
  if (!availDays) return gd;
  let r = '';
  for (let i = 0; i < 7; i++) r += (gd[i] === '1' && availDays[i] === '1') ? '1' : '0';
  return r;
}

// mask index: Mon=0 … Sun=6
function isDayScheduled(dateStr, mask) {
  if (!mask) return false;
  const dow = new Date(dateStr + 'T12:00:00Z').getUTCDay(); // 0=Sun
  const idx = dow === 0 ? 6 : dow - 1;
  return mask[idx] === '1';
}

async function recomputeStreak(userId, gymDays, userEntries, dbUser) {
  const mask = effectiveMask(gymDays, dbUser.avail_days);

  const entryMap = {};
  for (const e of userEntries) {
    if (!entryMap[e.date]) entryMap[e.date] = { attend: false, skip: false };
    if (e.type === 'attend' || e.type === 'late') entryMap[e.date].attend = true;
    if (e.type === 'skip') entryMap[e.date].skip = true;
  }

  const todayD = new Date();
  todayD.setUTCHours(12, 0, 0, 0);
  const todayStr = dateYMD(todayD);

  // Never look before user's join date
  const joinD = dbUser.created_at
    ? new Date(Number(dbUser.created_at))
    : new Date(todayD.getTime() - MAX_LOOKBACK * 86400000);
  joinD.setUTCHours(12, 0, 0, 0);

  let startD;
  if (dbUser.last_streak_date) {
    startD = new Date(dbUser.last_streak_date + 'T12:00:00Z');
    startD.setUTCDate(startD.getUTCDate() + 1);
  } else {
    startD = new Date(joinD);
  }
  // Cap to [joinD, todayD]
  if (startD < joinD) startD = new Date(joinD);
  if (startD > todayD) {
    return { streak: dbUser.streak, freezes: dbUser.freezes, last_streak_date: dbUser.last_streak_date };
  }

  let streak = Number(dbUser.streak) || 0;
  let freezes = Number(dbUser.freezes) || 0;
  let last_streak_date = dbUser.last_streak_date || null;
  let changed = false;

  for (let curD = new Date(startD); curD <= todayD; curD.setUTCDate(curD.getUTCDate() + 1)) {
    const dateStr = dateYMD(curD);
    const day = entryMap[dateStr] || {};

    if (day.attend) {
      // attendance always counts, regardless of scheduled day
      streak++;
      last_streak_date = dateStr;
      changed = true;
    } else if (isDayScheduled(dateStr, mask) && dateStr < todayStr) {
      // past scheduled day with no check-in → apply miss logic
      last_streak_date = dateStr;
      changed = true;
      if (day.skip) {
        // held — no streak change
      } else if (freezes > 0) {
        freezes--;
      } else {
        streak = 0;
      }
    }
    // non-scheduled day with no attend, or today with no attend → leave open
  }

  if (changed) {
    await database.run(
      'UPDATE users SET streak = ?, freezes = ?, last_streak_date = ? WHERE id = ?',
      [streak, freezes, last_streak_date, userId]
    );
  }

  return { streak, freezes, last_streak_date };
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
    avatarImg: u.avatar_img || null,
    isCreator: Number(u.is_creator) === 1,
  };
}

const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(e => {
  console.error(e);
  if (!res.headersSent) res.status(500).json({ error: 'internal' });
});

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '512kb' }));

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

function parseGeoCoords(body) {
  const lat = body?.gym_lat !== undefined ? Number(body.gym_lat) : null;
  const lng = body?.gym_lng !== undefined ? Number(body.gym_lng) : null;
  const radius = body?.gym_radius !== undefined ? Number(body.gym_radius) : null;
  if (lat !== null && (isNaN(lat) || lat < -90 || lat > 90)) return { error: 'invalid_gym_lat' };
  if (lng !== null && (isNaN(lng) || lng < -180 || lng > 180)) return { error: 'invalid_gym_lng' };
  if (radius !== null && (isNaN(radius) || radius < 20 || radius > 5000)) return { error: 'invalid_gym_radius' };
  return { lat: lat !== null && !isNaN(lat) ? lat : null,
           lng: lng !== null && !isNaN(lng) ? lng : null,
           radius: radius !== null && !isNaN(radius) ? Math.round(radius) : null };
}

app.post('/api/admin/verify', ah(async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: 'unauthorized' });
  res.json({ ok: true });
}));

app.post('/api/groups', ah(async (req, res) => {
  const name = String(req.body?.name ?? '').trim().slice(0, 50);
  const gymDays = String(req.body?.gym_days ?? '').trim();
  if (!name) return res.status(400).json({ error: 'name_required' });
  if (!isValidGymDays(gymDays)) return res.status(400).json({ error: 'invalid_gym_days' });
  const geo = parseGeoCoords(req.body);
  if (geo.error) return res.status(400).json({ error: geo.error });
  const id = crypto.randomUUID();
  const code = await uniqueCode();
  await database.run(
    'INSERT INTO `groups` (id,code,name,created_at,gym_days,gym_lat,gym_lng,gym_radius) VALUES (?,?,?,?,?,?,?,?)',
    [id, code, name, Date.now(), gymDays, geo.lat, geo.lng, geo.radius]
  );
  res.json({ id, code, name, gym_days: gymDays });
}));

app.patch('/api/groups/:id', ah(async (req, res) => {
  const { id } = req.params;
  const group = await database.one('SELECT id, creator_user_id FROM `groups` WHERE id = ?', [id]);
  if (!group) return res.status(404).json({ error: 'not_found' });

  // Auth: admin password OR creator + recovery code
  const admin = isAdmin(req);
  if (!admin) {
    const creatorUserId = String(req.body?.creatorUserId ?? '').trim();
    const creatorRecoveryCode = String(req.body?.creatorRecoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();
    if (!creatorUserId || !creatorRecoveryCode) return res.status(400).json({ error: 'missing_fields' });
    const actor = await database.one('SELECT id, recovery_code, is_creator FROM users WHERE id = ? AND group_id = ?', [creatorUserId, id]);
    if (!actor) return res.status(401).json({ error: 'unauthorized' });
    if (actor.recovery_code.replace(/-/g, '') !== creatorRecoveryCode) return res.status(401).json({ error: 'unauthorized' });
    if (Number(actor.is_creator) !== 1) return res.status(403).json({ error: 'not_creator' });
  }

  const sets = []; const params = [];

  if (req.body?.gym_days !== undefined) {
    const gymDays = String(req.body.gym_days).trim();
    if (!isValidGymDays(gymDays)) return res.status(400).json({ error: 'invalid_gym_days' });
    sets.push('gym_days = ?'); params.push(gymDays);
  }
  if (req.body?.name !== undefined) {
    const newName = String(req.body.name).trim().slice(0, 50);
    if (newName) { sets.push('name = ?'); params.push(newName); }
  }
  const geo = parseGeoCoords(req.body);
  if (geo.error) return res.status(400).json({ error: geo.error });
  if (req.body?.gym_lat !== undefined) { sets.push('gym_lat = ?'); params.push(geo.lat); }
  if (req.body?.gym_lng !== undefined) { sets.push('gym_lng = ?'); params.push(geo.lng); }
  if (req.body?.gym_radius !== undefined) { sets.push('gym_radius = ?'); params.push(geo.radius); }

  if (!sets.length) return res.json({ ok: true });
  params.push(id);
  await database.run(`UPDATE \`groups\` SET ${sets.join(', ')} WHERE id = ?`, params);
  res.json({ ok: true });
}));

app.post('/api/test-group', ah(async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: 'unauthorized' });

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
  const g = await database.one('SELECT id,code,name,creator_user_id,gym_days,gym_lat,gym_lng,gym_radius FROM `groups` WHERE id = ?', [req.params.id]);
  if (!g) return res.status(404).json({ error: 'not_found' });
  const rawUsers = await database.all(`
    SELECT id, name, avatar_emoji, avatar_color, avatar_img, is_creator,
           streak, freezes, last_streak_date, avail_days, avail_edited_at, created_at
    FROM users WHERE group_id = ? ORDER BY created_at
  `, [req.params.id]);
  const allEntries = await database.all('SELECT id,person,date,mins,ts,type,reason FROM entries WHERE group_id = ? ORDER BY date DESC, ts DESC', [req.params.id]);

  const byPerson = {};
  for (const e of allEntries) { (byPerson[e.person] = byPerson[e.person] || []).push(e); }

  const people = [];
  for (const u of rawUsers) {
    const s = await recomputeStreak(u.id, g.gym_days, byPerson[u.name] || [], u);
    people.push({
      ...userDto(u),
      streak: s.streak,
      freezes: s.freezes,
      availDays: u.avail_days || null,
      availEditedAt: u.avail_edited_at || null,
    });
  }

  res.json({ id: g.id, code: g.code, name: g.name, gymDays: g.gym_days,
    gymLat: g.gym_lat ?? null, gymLng: g.gym_lng ?? null, gymRadius: g.gym_radius ?? null,
    people, entries: allEntries });
}));

// ── Users ────────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/users', ah(async (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim().slice(0, 30);
  const avatarEmoji = String(req.body?.avatarEmoji ?? '🏋️');
  const avatarColor = String(req.body?.avatarColor ?? '#7c3aed');
  const avatarImg = req.body?.avatarImg ? String(req.body.avatarImg) : null;

  if (!name) return res.status(400).json({ error: 'name_required' });
  if (avatarImg && (!avatarImg.startsWith('data:image/') || avatarImg.length > 400000)) {
    return res.status(400).json({ error: 'invalid_avatar_img' });
  }
  const g = await database.one('SELECT id, creator_user_id FROM `groups` WHERE id = ?', [id]);
  if (!g) return res.status(404).json({ error: 'not_found' });

  const userId = crypto.randomUUID();
  const recoveryCode = genRecoveryCode();
  const isCreator = g.creator_user_id === null ? 1 : 0;
  const now = Date.now();

  try {
    await database.run(`
      INSERT INTO users (id, group_id, name, recovery_code, avatar_emoji, avatar_color, avatar_img, is_creator, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [userId, id, name, recoveryCode, avatarEmoji, avatarColor, avatarImg, isCreator, now]);

    await database.run(`${insertIgnore()} INTO members (id, group_id, name, created_at) VALUES (?,?,?,?)`, [userId, id, name, now]);

    if (isCreator) {
      await database.run('UPDATE `groups` SET creator_user_id = ? WHERE id = ? AND creator_user_id IS NULL', [userId, id]);
    }

    res.json({ userId, name, avatarEmoji, avatarColor, avatarImg, recoveryCode, isCreator: isCreator === 1 });
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
    SELECT id, name, avatar_emoji, avatar_color, avatar_img, is_creator, recovery_code
    FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)
  `, [id, name]);

  if (!user) return res.status(404).json({ error: 'user_not_found' });
  if (user.recovery_code.replace(/-/g, '') !== recoveryCode) return res.status(401).json({ error: 'wrong_code' });

  res.json({
    userId: user.id,
    name: user.name,
    avatarEmoji: user.avatar_emoji,
    avatarColor: user.avatar_color,
    avatarImg: user.avatar_img || null,
    isCreator: Number(user.is_creator) === 1,
  });
}));

app.patch('/api/groups/:id/users/:uid', ah(async (req, res) => {
  const { id, uid } = req.params;
  const admin = isAdmin(req);
  const recoveryCode = String(req.body?.recoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();

  const user = await database.one('SELECT id, recovery_code, name, avail_edited_at FROM users WHERE id = ? AND group_id = ?', [uid, id]);
  if (!user) return res.status(404).json({ error: 'not_found' });
  if (!admin && user.recovery_code.replace(/-/g, '') !== recoveryCode) return res.status(401).json({ error: 'unauthorized' });

  const newName = req.body?.name ? String(req.body.name).trim().slice(0, 30) : null;
  const newEmoji = req.body?.avatarEmoji ? String(req.body.avatarEmoji) : null;
  const newColor = req.body?.avatarColor ? String(req.body.avatarColor) : null;

  const sets = [];
  const params = [];
  if (newName) { sets.push('name = ?'); params.push(newName); }
  if (newEmoji) { sets.push('avatar_emoji = ?'); params.push(newEmoji); }
  if (newColor) { sets.push('avatar_color = ?'); params.push(newColor); }
  if (Object.prototype.hasOwnProperty.call(req.body, 'avatarImg')) {
    const imgVal = req.body.avatarImg ? String(req.body.avatarImg) : null;
    if (imgVal && (!imgVal.startsWith('data:image/') || imgVal.length > 400000)) {
      return res.status(400).json({ error: 'invalid_avatar_img' });
    }
    sets.push('avatar_img = ?');
    params.push(imgVal);
  }
  if (Object.prototype.hasOwnProperty.call(req.body, 'avail_days')) {
    const rawAvail = req.body.avail_days === null ? null : String(req.body.avail_days).trim();
    if (rawAvail !== null && !isValidGymDays(rawAvail)) {
      return res.status(400).json({ error: 'invalid_avail_days' });
    }
    if (!admin) {
      const editedAt = user.avail_edited_at ? Number(user.avail_edited_at) : null;
      if (editedAt) {
        const elapsed = Date.now() - editedAt;
        if (elapsed > LOCK_OPEN_MS && elapsed < LOCK_DURATION_MS) {
          return res.status(403).json({ error: 'avail_locked', remaining_ms: Math.round(LOCK_DURATION_MS - elapsed) });
        }
      }
    }
    sets.push('avail_days = ?', 'avail_edited_at = ?');
    params.push(rawAvail, Date.now());
  }
  // Admin-only: edit streak and freezes directly
  if (admin) {
    if (req.body?.streak !== undefined) {
      const sv = Math.max(0, Math.floor(Number(req.body.streak)));
      if (!isNaN(sv)) { sets.push('streak = ?'); params.push(sv); }
    }
    if (req.body?.freezes !== undefined) {
      const fv = Math.min(10, Math.max(0, Math.floor(Number(req.body.freezes))));
      if (!isNaN(fv)) { sets.push('freezes = ?'); params.push(fv); }
    }
  }
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
  if (!isAdmin(req)) {
    const actorId = String(req.body?.actorUserId ?? '');
    const actorCode = String(req.body?.actorRecoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();
    const actor = await database.one('SELECT id, recovery_code, is_creator FROM users WHERE id = ? AND group_id = ?', [actorId, id]);
    if (!actor) return res.status(401).json({ error: 'unauthorized' });
    if (actor.recovery_code.replace(/-/g, '') !== actorCode) return res.status(401).json({ error: 'unauthorized' });
    if (Number(actor.is_creator) !== 1) return res.status(403).json({ error: 'not_creator' });
    if (uid === actorId) return res.status(400).json({ error: 'cannot_kick_self' });
  }

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
  const date   = String(req.body?.date   ?? '').trim();
  const type   = ['late', 'skip', 'attend'].includes(req.body?.type) ? req.body.type : 'late';
  const reason = (type === 'skip' && req.body?.reason) ? String(req.body.reason).trim().slice(0, 20) : null;
  const mins   = (type === 'skip' || type === 'attend') ? 0 : parseInt(req.body?.mins);
  if (!person || !date) return res.status(400).json({ error: 'invalid' });
  if (type === 'late' && (isNaN(mins) || mins < 1 || mins > 999)) return res.status(400).json({ error: 'invalid' });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return res.status(400).json({ error: 'invalid_date' });
  const g = await database.one('SELECT id, gym_days FROM `groups` WHERE id = ?', [id]);
  if (!g) return res.status(404).json({ error: 'not_found' });

  const eid = crypto.randomUUID();
  const now = Date.now();
  await database.run('INSERT INTO entries (id,group_id,person,date,mins,ts,type,reason) VALUES (?,?,?,?,?,?,?,?)',
    [eid, id, person, date, mins, now, type, reason]);

  let chest = null;
  if (type === 'attend') {
    const dbUser = await database.one(
      'SELECT id, streak, freezes, last_streak_date, avail_days, last_freeze_grant, created_at FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)',
      [id, person]
    );
    if (dbUser) {
      // Chest roll
      const byPity = dbUser.freezes === 0 && (!dbUser.last_freeze_grant || (now - Number(dbUser.last_freeze_grant)) >= PITY_MS);
      const byRoll = !byPity && Number(dbUser.freezes) < 2 && Math.random() < 0.05;
      const gotFreeze = (byPity || byRoll) && Number(dbUser.freezes) < 2;
      if (gotFreeze) {
        // Compute in JS — MySQL's MIN() is aggregate-only (scalar version is LEAST),
        // SQLite has no LEAST; a plain bound value works on both engines.
        const newFreezes = Math.min(2, Number(dbUser.freezes) + 1);
        await database.run(
          'UPDATE users SET freezes = ?, last_freeze_grant = ? WHERE id = ?',
          [newFreezes, now, dbUser.id]
        );
        dbUser.last_freeze_grant = now;
        dbUser.freezes = newFreezes;
      }
      // Recompute streak to include today's check-in
      const userEntries = await database.all(
        'SELECT date, type FROM entries WHERE group_id = ? AND LOWER(person) = LOWER(?)',
        [id, person]
      );
      const s = await recomputeStreak(dbUser.id, g.gym_days, userEntries, dbUser);
      chest = { got_freeze: gotFreeze, streak: s.streak, freezes: s.freezes };
    }
  }

  res.json({ ok: true, id: eid, chest });
}));

app.delete('/api/groups/:id/entries/:eid', ah(async (req, res) => {
  const { id, eid } = req.params;
  if (!isAdmin(req)) {
    // Require creator auth for non-admin deletes
    const actorId = String(req.body?.actorUserId ?? '');
    const actorCode = String(req.body?.actorRecoveryCode ?? '').replace(/-/g, '').trim().toUpperCase();
    if (!actorId) return res.status(401).json({ error: 'unauthorized' });
    const actor = await database.one('SELECT recovery_code, is_creator FROM users WHERE id = ? AND group_id = ?', [actorId, id]);
    if (!actor) return res.status(401).json({ error: 'unauthorized' });
    if (actor.recovery_code.replace(/-/g, '') !== actorCode) return res.status(401).json({ error: 'unauthorized' });
    if (Number(actor.is_creator) !== 1) return res.status(403).json({ error: 'not_creator' });
  }
  await database.run('DELETE FROM entries WHERE id = ? AND group_id = ?', [eid, id]);
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
