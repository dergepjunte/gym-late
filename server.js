'use strict';

const express = require('express');
const crypto  = require('crypto');
const path    = require('path');
const fs      = require('fs');

// ── Push Notification providers (optional — graceful no-op if env vars absent) ─
let webpush = null;
let apnProvider = null;

try {
  webpush = require('web-push');
  const vPub = process.env.VAPID_PUBLIC_KEY;
  const vPri = process.env.VAPID_PRIVATE_KEY;
  const vMail = process.env.VAPID_EMAIL || 'mailto:admin@gymlate.app';
  if (vPub && vPri) {
    webpush.setVapidDetails(vMail, vPub, vPri);
    console.log('🔔 Web Push (VAPID) ready');
  } else {
    console.log('ℹ️  Web Push disabled — set VAPID_PUBLIC_KEY + VAPID_PRIVATE_KEY to enable');
    webpush = null;
  }
} catch { webpush = null; }

try {
  const apnLib = require('apn');
  const p8 = process.env.APNS_KEY_P8;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  if (p8 && keyId && teamId) {
    apnProvider = new apnLib.Provider({
      token: { key: p8, keyId, teamId },
      production: process.env.NODE_ENV === 'production',
    });
    apnProvider._Notification = apnLib.Notification;
    console.log('🍎 APNs ready (' + (process.env.NODE_ENV === 'production' ? 'prod' : 'sandbox') + ')');
  } else {
    console.log('ℹ️  APNs disabled — set APNS_KEY_P8 + APNS_KEY_ID + APNS_TEAM_ID to enable');
  }
} catch { apnProvider = null; }



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

  // Serializes transactions: the async callback yields at await points, so a
  // concurrent request could otherwise issue a nested BEGIN on this connection.
  let txChain = Promise.resolve();

  return {
    isMySQL: false,
    exec(sql) { sqlite.exec(sql); },
    async run(sql, params = []) { return sqlite.prepare(sql).run(...params); },
    async one(sql, params = []) { return sqlite.prepare(sql).get(...params) || null; },
    async all(sql, params = []) { return sqlite.prepare(sql).all(...params); },
    async transaction(fn) {
      // better-sqlite3's own transaction() rejects async callbacks, so manage
      // BEGIN/COMMIT/ROLLBACK manually — mirroring the MySQL wrapper below.
      const exec = async () => {
        sqlite.exec('BEGIN');
        try {
          const result = await fn(this);
          sqlite.exec('COMMIT');
          return result;
        } catch (e) {
          if (sqlite.inTransaction) sqlite.exec('ROLLBACK');
          throw e;
        }
      };
      const p = txChain.then(exec, exec);
      txChain = p.catch(() => {});
      return p;
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
        gym_radius INT NULL,
        fixed_checkin_enabled TINYINT NOT NULL DEFAULT 0,
        checkin_time_date VARCHAR(10) NULL,
        checkin_time VARCHAR(5) NULL
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
    try { await database.run('ALTER TABLE `groups` ADD COLUMN fixed_checkin_enabled TINYINT NOT NULL DEFAULT 0'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE `groups` ADD COLUMN checkin_time_date VARCHAR(10) NULL'); } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try { await database.run('ALTER TABLE `groups` ADD COLUMN checkin_time VARCHAR(5) NULL'); } catch (e) {
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
    // Push notification tables
    await database.run(`
      CREATE TABLE IF NOT EXISTS push_subscriptions (
        id VARCHAR(36) PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NOT NULL,
        endpoint TEXT NOT NULL,
        p256dh TEXT NOT NULL,
        auth TEXT NOT NULL,
        created_at BIGINT NOT NULL,
        UNIQUE KEY uniq_push_sub (user_id, group_id),
        INDEX idx_push_sub_user (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    await database.run(`
      CREATE TABLE IF NOT EXISTS apns_tokens (
        id VARCHAR(36) PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NOT NULL,
        token VARCHAR(200) NOT NULL,
        created_at BIGINT NOT NULL,
        UNIQUE KEY uniq_apns (user_id, group_id),
        INDEX idx_apns_user (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    await database.run(`
      CREATE TABLE IF NOT EXISTS push_log (
        id VARCHAR(36) PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NOT NULL,
        type VARCHAR(80) NOT NULL,
        sent_date CHAR(10) NOT NULL,
        INDEX idx_push_log (user_id, group_id, type, sent_date)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    // Notification preference columns on users
    const notifCols = [
      ["notif_reminders", "TINYINT NOT NULL DEFAULT 1"],
      ["notif_streak",    "TINYINT NOT NULL DEFAULT 1"],
      ["notif_activity",  "TINYINT NOT NULL DEFAULT 1"],
      ["reminder_time",   "CHAR(5) NOT NULL DEFAULT '09:00'"],
      ["quiet_start",     "CHAR(5) NOT NULL DEFAULT '22:00'"],
      ["quiet_end",       "CHAR(5) NOT NULL DEFAULT '08:00'"],
      ["timezone",        "VARCHAR(50) NOT NULL DEFAULT 'UTC'"],
      ["notif_members",   "TEXT NULL"],
    ];
    for (const [col, def] of notifCols) {
      try { await database.run(`ALTER TABLE users ADD COLUMN ${col} ${def}`); } catch (e) {
        if (e.code !== 'ER_DUP_FIELDNAME') throw e;
      }
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
      gym_radius INTEGER,
      fixed_checkin_enabled INTEGER NOT NULL DEFAULT 0,
      checkin_time_date TEXT,
      checkin_time TEXT
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
  try { database.exec('ALTER TABLE `groups` ADD COLUMN fixed_checkin_enabled INTEGER NOT NULL DEFAULT 0'); } catch {}
  try { database.exec('ALTER TABLE `groups` ADD COLUMN checkin_time_date TEXT'); } catch {}
  try { database.exec('ALTER TABLE `groups` ADD COLUMN checkin_time TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avatar_img TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avail_days TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN avail_edited_at INTEGER'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN streak INTEGER NOT NULL DEFAULT 0'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN freezes INTEGER NOT NULL DEFAULT 0'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN last_streak_date TEXT'); } catch {}
  try { database.exec('ALTER TABLE users ADD COLUMN last_freeze_grant INTEGER'); } catch {}
  try { database.exec("ALTER TABLE entries ADD COLUMN type TEXT NOT NULL DEFAULT 'late'"); } catch {}
  try { database.exec('ALTER TABLE entries ADD COLUMN reason TEXT'); } catch {}

  // Push notification tables
  database.exec(`
    CREATE TABLE IF NOT EXISTS push_subscriptions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      endpoint TEXT NOT NULL,
      p256dh TEXT NOT NULL,
      auth TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(user_id, group_id)
    );
    CREATE TABLE IF NOT EXISTS apns_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      token TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(user_id, group_id)
    );
    CREATE TABLE IF NOT EXISTS push_log (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      type TEXT NOT NULL,
      sent_date TEXT NOT NULL
    );
  `);
  try { database.exec("CREATE INDEX IF NOT EXISTS idx_push_log ON push_log(user_id, group_id, type, sent_date)"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN notif_reminders INTEGER NOT NULL DEFAULT 1"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN notif_streak INTEGER NOT NULL DEFAULT 1"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN notif_activity INTEGER NOT NULL DEFAULT 1"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN reminder_time TEXT NOT NULL DEFAULT '09:00'"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN quiet_start TEXT NOT NULL DEFAULT '22:00'"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN quiet_end TEXT NOT NULL DEFAULT '08:00'"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN timezone TEXT NOT NULL DEFAULT 'UTC'"); } catch {}
  try { database.exec("ALTER TABLE users ADD COLUMN notif_members TEXT NULL"); } catch {}
}

// ── Push notification helpers ────────────────────────────────────────────────

function localHHMM(timezone) {
  try {
    return new Date().toLocaleTimeString('en-US', {
      timeZone: timezone || 'UTC', hour12: false, hour: '2-digit', minute: '2-digit',
    }).replace(/^24:/, '00:');
  } catch { return new Date().toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' }).replace(/^24:/, '00:'); }
}

function isInQuietHours(user) {
  const qs = user.quiet_start || '22:00';
  const qe = user.quiet_end   || '08:00';
  const cur = localHHMM(user.timezone);
  const [qsh, qsm] = qs.split(':').map(Number);
  const [qeh, qem] = qe.split(':').map(Number);
  const [ch,  cm]  = cur.split(':').map(Number);
  const qsn = qsh * 60 + qsm, qen = qeh * 60 + qem, cn = ch * 60 + cm;
  return qsn <= qen ? (cn >= qsn && cn < qen) : (cn >= qsn || cn < qen);
}

function isTimeNow(hhmm, timezone) {
  return localHHMM(timezone) === hhmm;
}

function subtractOneHour(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return `${String((h - 1 + 24) % 24).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

async function sendPushToUser(userId, groupId, payload) {
  const tag = JSON.stringify(payload);

  if (webpush) {
    const subs = await database.all(
      'SELECT id, endpoint, p256dh, auth FROM push_subscriptions WHERE user_id = ? AND group_id = ?',
      [userId, groupId]
    );
    for (const sub of subs) {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          JSON.stringify({ title: payload.title, body: payload.body, icon: '/icon-192.png', tag: payload.tag || payload.title })
        );
      } catch (e) {
        if (e.statusCode === 410 || e.statusCode === 404) {
          await database.run('DELETE FROM push_subscriptions WHERE id = ?', [sub.id]);
        }
      }
    }
  }

  if (apnProvider) {
    const tokens = await database.all(
      'SELECT id, token FROM apns_tokens WHERE user_id = ? AND group_id = ?',
      [userId, groupId]
    );
    for (const row of tokens) {
      const note = new apnProvider._Notification();
      note.expiry = Math.floor(Date.now() / 1000) + 3600;
      note.badge = 1;
      note.sound = 'default';
      note.alert = { title: payload.title, body: payload.body };
      note.topic = process.env.APNS_BUNDLE_ID || 'com.gymlate.app';
      note.payload = { tag: payload.tag || '' };
      const result = await apnProvider.send(note, row.token);
      if (result.failed.length) {
        const reason = result.failed[0]?.response?.reason;
        if (reason === 'BadDeviceToken' || reason === 'Unregistered') {
          await database.run('DELETE FROM apns_tokens WHERE id = ?', [row.id]);
        }
      }
    }
  }
}

async function sendActivityPush(groupId, actorUserId, actorName, entryType) {
  if (!webpush && !apnProvider) return;
  const today = dateYMD(new Date());
  const emoji = entryType === 'late' ? '⏰' : '💪';
  const body = entryType === 'late' ? `checked in (a bit late) 🏋️` : `just checked in 🏋️`;
  try {
    const others = await database.all(
      `SELECT id, notif_members, quiet_start, quiet_end, timezone
       FROM users WHERE group_id = ? AND id != ? AND notif_activity = 1`,
      [groupId, actorUserId]
    );
    for (const u of others) {
      if (u.notif_members) {
        try {
          const allowed = JSON.parse(u.notif_members);
          if (Array.isArray(allowed) && !allowed.includes(actorUserId)) continue;
        } catch {}
      }
      if (isInQuietHours(u)) continue;
      const logType = `activity:${actorUserId}`;
      const already = await database.one(
        'SELECT 1 AS x FROM push_log WHERE user_id = ? AND group_id = ? AND type = ? AND sent_date = ?',
        [u.id, groupId, logType, today]
      );
      if (already) continue;
      await sendPushToUser(u.id, groupId, {
        title: `${emoji} ${actorName}`, body, tag: `activity-${actorUserId}-${today}`,
      });
      await database.run(
        'INSERT INTO push_log (id, user_id, group_id, type, sent_date) VALUES (?, ?, ?, ?, ?)',
        [crypto.randomUUID(), u.id, groupId, logType, today]
      );
    }
  } catch (e) { console.error('sendActivityPush error:', e); }
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

// fullReplay: ignore the last_streak_date watermark and recompute from the
// join date (capped to MAX_LOOKBACK). Needed when entries are backdated or
// deleted — the watermark fast path can only ever move forward.
async function recomputeStreak(userId, gymDays, userEntries, dbUser, fullReplay = false) {
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

  // Attendance counts anywhere in the lookback window (users may backdate
  // check-ins from before they joined); misses only apply from the join date.
  const joinStr = dateYMD(joinD);
  const minStart = new Date(todayD.getTime() - MAX_LOOKBACK * 86400000);

  let startD;
  if (!fullReplay && dbUser.last_streak_date) {
    startD = new Date(dbUser.last_streak_date + 'T12:00:00Z');
    startD.setUTCDate(startD.getUTCDate() + 1);
  } else {
    startD = new Date(minStart);
  }
  if (startD < minStart) startD = new Date(minStart);
  if (startD > todayD) {
    return { streak: dbUser.streak, freezes: dbUser.freezes, last_streak_date: dbUser.last_streak_date };
  }

  let streak = fullReplay ? 0 : (Number(dbUser.streak) || 0);
  let freezes = Number(dbUser.freezes) || 0;
  let last_streak_date = fullReplay ? null : (dbUser.last_streak_date || null);
  let changed = fullReplay;

  for (let curD = new Date(startD); curD <= todayD; curD.setUTCDate(curD.getUTCDate() + 1)) {
    const dateStr = dateYMD(curD);
    const day = entryMap[dateStr] || {};

    if (day.attend) {
      // attendance always counts, regardless of scheduled day
      streak++;
      last_streak_date = dateStr;
      changed = true;
    } else if (isDayScheduled(dateStr, mask) && dateStr < todayStr && dateStr >= joinStr) {
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
// PWA icons: pre-rendered static PNGs from web-icons/
// Regenerate with: python3 GymLate/Scripts/generate_app_icon.py
const iconsDir = path.join(__dirname, 'web-icons');
const iconCache = {};
function getStaticIcon(name) {
  if (!iconCache[name]) iconCache[name] = fs.readFileSync(path.join(iconsDir, name));
  return iconCache[name];
}
const iconHeaders = (res) => {
  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Cache-Control', 'public, max-age=86400');
};
app.get('/apple-touch-icon.png',         (_, res) => { iconHeaders(res); res.send(getStaticIcon('apple-touch-icon-180.png')); });
app.get('/apple-touch-icon-180x180.png', (_, res) => { iconHeaders(res); res.send(getStaticIcon('apple-touch-icon-180.png')); });
app.get('/icon-192.png',                 (_, res) => { iconHeaders(res); res.send(getStaticIcon('icon-192.png')); });
app.get('/icon-512.png',                 (_, res) => { iconHeaders(res); res.send(getStaticIcon('icon-512.png')); });

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

// ── Push Notification routes ─────────────────────────────────────────────────

app.get('/api/push/vapid-public-key', (req, res) => {
  const key = process.env.VAPID_PUBLIC_KEY;
  if (!key) return res.status(503).json({ error: 'push_not_configured' });
  res.json({ key });
});

// Web Push subscription (browser → server)
app.post('/api/push/subscribe', ah(async (req, res) => {
  const { userId, groupId, recoveryCode, subscription } = req.body || {};
  if (!userId || !groupId || !subscription?.endpoint) return res.status(400).json({ error: 'invalid' });
  const user = await database.one('SELECT id, recovery_code FROM users WHERE id = ? AND group_id = ?', [userId, groupId]);
  if (!user) return res.status(404).json({ error: 'not_found' });
  if (user.recovery_code.replace(/-/g, '') !== String(recoveryCode || '').replace(/-/g, '').toUpperCase()) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  await database.run(
    `INSERT INTO push_subscriptions (id, user_id, group_id, endpoint, p256dh, auth, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE endpoint = VALUES(endpoint), p256dh = VALUES(p256dh), auth = VALUES(auth)`,
    [crypto.randomUUID(), userId, groupId, subscription.endpoint, subscription.keys.p256dh, subscription.keys.auth, Date.now()]
  ).catch(async () => {
    // SQLite: upsert via delete+insert
    await database.run('DELETE FROM push_subscriptions WHERE user_id = ? AND group_id = ?', [userId, groupId]);
    await database.run(
      'INSERT INTO push_subscriptions (id, user_id, group_id, endpoint, p256dh, auth, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [crypto.randomUUID(), userId, groupId, subscription.endpoint, subscription.keys.p256dh, subscription.keys.auth, Date.now()]
    );
  });
  res.json({ ok: true });
}));

app.delete('/api/push/subscribe', ah(async (req, res) => {
  const { userId, groupId } = req.body || {};
  if (userId && groupId) await database.run('DELETE FROM push_subscriptions WHERE user_id = ? AND group_id = ?', [userId, groupId]);
  res.json({ ok: true });
}));

// APNs device token (iOS → server)
app.post('/api/push/apns-token', ah(async (req, res) => {
  const { userId, groupId, recoveryCode, token } = req.body || {};
  if (!userId || !groupId || !token) return res.status(400).json({ error: 'invalid' });
  const user = await database.one('SELECT id, recovery_code FROM users WHERE id = ? AND group_id = ?', [userId, groupId]);
  if (!user) return res.status(404).json({ error: 'not_found' });
  if (user.recovery_code.replace(/-/g, '') !== String(recoveryCode || '').replace(/-/g, '').toUpperCase()) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  await database.run(
    `INSERT INTO apns_tokens (id, user_id, group_id, token, created_at)
     VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE token = VALUES(token)`,
    [crypto.randomUUID(), userId, groupId, token, Date.now()]
  ).catch(async () => {
    await database.run('DELETE FROM apns_tokens WHERE user_id = ? AND group_id = ?', [userId, groupId]);
    await database.run('INSERT INTO apns_tokens (id, user_id, group_id, token, created_at) VALUES (?, ?, ?, ?, ?)',
      [crypto.randomUUID(), userId, groupId, token, Date.now()]);
  });
  res.json({ ok: true });
}));

// Save notification preferences
app.patch('/api/groups/:id/users/:uid/notif', ah(async (req, res) => {
  const { id, uid } = req.params;
  const user = await database.one('SELECT id, recovery_code FROM users WHERE id = ? AND group_id = ?', [uid, id]);
  if (!user) return res.status(404).json({ error: 'not_found' });
  const rc = String(req.body?.recoveryCode || '').replace(/-/g, '').toUpperCase();
  if (!isAdmin(req) && user.recovery_code.replace(/-/g, '') !== rc) return res.status(401).json({ error: 'unauthorized' });

  const sets = []; const params = [];
  const boolField = (key, col) => {
    if (req.body?.[key] !== undefined) { sets.push(`${col} = ?`); params.push(req.body[key] ? 1 : 0); }
  };
  const strField = (key, col, validator) => {
    if (req.body?.[key] !== undefined) {
      const v = String(req.body[key]).trim();
      if (validator && !validator(v)) return;
      sets.push(`${col} = ?`); params.push(v);
    }
  };
  boolField('notifReminders', 'notif_reminders');
  boolField('notifStreak',    'notif_streak');
  boolField('notifActivity',  'notif_activity');
  strField('reminderTime', 'reminder_time', isValidTimeHHMM);
  strField('quietStart',   'quiet_start',   isValidTimeHHMM);
  strField('quietEnd',     'quiet_end',     isValidTimeHHMM);
  strField('timezone',     'timezone',      v => v.length <= 50);
  if (req.body?.notifMembers !== undefined) {
    sets.push('notif_members = ?');
    params.push(req.body.notifMembers === null ? null : JSON.stringify(req.body.notifMembers));
  }
  if (!sets.length) return res.json({ ok: true });
  params.push(uid, id);
  await database.run(`UPDATE users SET ${sets.join(', ')} WHERE id = ? AND group_id = ?`, params);
  res.json({ ok: true });
}));

// Admin: send test push notification with 10-second delay
app.post('/api/admin/test-push', ah(async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: 'unauthorized' });
  const { userId, groupId, type } = req.body || {};
  if (!userId || !groupId || !type) return res.status(400).json({ error: 'invalid' });

  const payloads = {
    reminder: { title: '💪 Gym day!',      body: "Don't forget to check in today",     tag: 'test-reminder' },
    streak:   { title: '🔥 Streak at risk!', body: 'Check in today to keep your streak alive', tag: 'test-streak' },
    activity: { title: 'GymLate',           body: 'Someone just checked in 💪',          tag: 'test-activity' },
  };

  const toSend = type === 'all' ? Object.values(payloads) : [payloads[type]];
  if (!toSend[0]) return res.status(400).json({ error: 'unknown_type' });

  for (const payload of toSend) {
    setTimeout(() => { sendPushToUser(userId, groupId, payload).catch(() => {}); }, 10000);
  }
  res.json({ ok: true, delay: 10, count: toSend.length });
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
  if (req.body?.fixed_checkin_enabled !== undefined) {
    sets.push('fixed_checkin_enabled = ?');
    params.push(req.body.fixed_checkin_enabled ? 1 : 0);
  }

  if (!sets.length) return res.json({ ok: true });
  params.push(id);
  await database.run(`UPDATE \`groups\` SET ${sets.join(', ')} WHERE id = ?`, params);
  res.json({ ok: true });
}));

function isValidTimeHHMM(v) {
  return typeof v === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(v);
}

// Any member may set today's fixed check-in time (mirrors the low-auth model
// of POST .../entries — whoever opens the app first sets the time for the day).
app.post('/api/groups/:id/checkin-time', ah(async (req, res) => {
  const { id } = req.params;
  const date = String(req.body?.date ?? '').trim();
  const time = String(req.body?.time ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return res.status(400).json({ error: 'invalid_date' });
  if (!isValidTimeHHMM(time)) return res.status(400).json({ error: 'invalid_time' });
  const g = await database.one('SELECT id, fixed_checkin_enabled FROM `groups` WHERE id = ?', [id]);
  if (!g) return res.status(404).json({ error: 'not_found' });
  if (!Number(g.fixed_checkin_enabled)) return res.status(400).json({ error: 'feature_disabled' });
  await database.run('UPDATE `groups` SET checkin_time_date = ?, checkin_time = ? WHERE id = ?', [date, time, id]);
  res.json({ ok: true, date, time });
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
  const g = await database.one('SELECT id,code,name,creator_user_id,gym_days,gym_lat,gym_lng,gym_radius,fixed_checkin_enabled,checkin_time_date,checkin_time FROM `groups` WHERE id = ?', [req.params.id]);
  if (!g) return res.status(404).json({ error: 'not_found' });
  const rawUsers = await database.all(`
    SELECT id, name, avatar_emoji, avatar_color, avatar_img, is_creator,
           streak, freezes, last_streak_date, avail_days, avail_edited_at, created_at
    FROM users WHERE group_id = ? ORDER BY created_at
  `, [req.params.id]);
  const allEntries = await database.all('SELECT id,person,date,mins,ts,type,reason FROM entries WHERE group_id = ? ORDER BY date DESC, ts DESC', [req.params.id]);

  // Key case-insensitively — entry person names are free text and the
  // POST /entries user lookup is LOWER()-based; a case mismatch here made
  // the recompute miss attendances and falsely reset streaks.
  const byPerson = {};
  for (const e of allEntries) {
    const k = (e.person || '').toLowerCase();
    (byPerson[k] = byPerson[k] || []).push(e);
  }

  const people = [];
  for (const u of rawUsers) {
    const s = await recomputeStreak(u.id, g.gym_days, byPerson[(u.name || '').toLowerCase()] || [], u);
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
    fixedCheckinEnabled: Boolean(Number(g.fixed_checkin_enabled)),
    checkinTimeDate: g.checkin_time_date ?? null, checkinTime: g.checkin_time ?? null,
    people, entries: allEntries });
}));

// ── Users ────────────────────────────────────────────────────────────────────

app.post('/api/groups/:id/users', ah(async (req, res) => {
  const { id } = req.params;
  const name = String(req.body?.name ?? '').trim().slice(0, 30);
  const avatarEmoji = String(req.body?.avatarEmoji ?? '🏋️').slice(0, 16);
  const avatarColor = String(req.body?.avatarColor ?? '#7c3aed').slice(0, 16);
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
  const newEmoji = req.body?.avatarEmoji ? String(req.body.avatarEmoji).slice(0, 16) : null;
  const newColor = req.body?.avatarColor ? String(req.body.avatarColor).slice(0, 16) : null;

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
  if (type === 'attend' || type === 'late') {
    const dbUser = await database.one(
      'SELECT id, streak, freezes, last_streak_date, avail_days, last_freeze_grant, created_at FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)',
      [id, person]
    );
    if (dbUser) {
      let gotFreeze = false;
      if (type === 'attend') {
        // Chest roll
        const byPity = Number(dbUser.freezes) === 0 && (!dbUser.last_freeze_grant || (now - Number(dbUser.last_freeze_grant)) >= PITY_MS);
        const byRoll = !byPity && Number(dbUser.freezes) < 2 && Math.random() < 0.05;
        gotFreeze = (byPity || byRoll) && Number(dbUser.freezes) < 2;
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
      }
      // Recompute streak; a backdated entry lands behind the watermark and
      // needs a full replay, otherwise it would never count.
      const userEntries = await database.all(
        'SELECT date, type FROM entries WHERE group_id = ? AND LOWER(person) = LOWER(?)',
        [id, person]
      );
      const backdated = Boolean(dbUser.last_streak_date && date <= dbUser.last_streak_date);
      const s = await recomputeStreak(dbUser.id, g.gym_days, userEntries, dbUser, backdated);
      if (type === 'attend') chest = { got_freeze: gotFreeze, streak: s.streak, freezes: s.freezes };
    }
  }

  // Fire activity push after response (non-blocking)
  if (type === 'attend' || type === 'late') {
    const actorId = (await database.one(
      'SELECT id FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)', [id, person]
    ))?.id || null;
    setImmediate(() => sendActivityPush(id, actorId, person, type).catch(() => {}));
  }

  res.json({ ok: true, id: eid, chest });
}));

app.patch('/api/groups/:id/entries/:eid', ah(async (req, res) => {
  const { id, eid } = req.params;
  if (!isAdmin(req)) return res.status(403).json({ error: 'not_admin' });

  const old = await database.one('SELECT person, date, type FROM entries WHERE id = ? AND group_id = ?', [eid, id]);
  if (!old) return res.status(404).json({ error: 'not_found' });

  const type   = ['late', 'skip', 'attend'].includes(req.body?.type) ? req.body.type : old.type;
  const date   = String(req.body?.date ?? old.date).trim();
  const reason = (type === 'skip' && req.body?.reason) ? String(req.body.reason).trim().slice(0, 20) : null;
  const mins   = (type === 'skip' || type === 'attend') ? 0 : parseInt(req.body?.mins);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return res.status(400).json({ error: 'invalid_date' });
  if (type === 'late' && (isNaN(mins) || mins < 1 || mins > 999)) return res.status(400).json({ error: 'invalid' });

  await database.run('UPDATE entries SET date = ?, mins = ?, type = ?, reason = ? WHERE id = ? AND group_id = ?',
    [date, mins, type, reason, eid, id]);

  const g = await database.one('SELECT gym_days FROM `groups` WHERE id = ?', [id]);
  const dbUser = await database.one(
    'SELECT id, streak, freezes, last_streak_date, avail_days, last_freeze_grant, created_at FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)',
    [id, old.person]
  );
  if (dbUser) {
    const userEntries = await database.all(
      'SELECT date, type FROM entries WHERE group_id = ? AND LOWER(person) = LOWER(?)',
      [id, old.person]
    );
    // Edit can move type/date arbitrarily — force a full replay to stay correct.
    await recomputeStreak(dbUser.id, g.gym_days, userEntries, dbUser, true);
  }

  res.json({ ok: true });
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
  const entry = await database.one('SELECT person, date, type FROM entries WHERE id = ? AND group_id = ?', [eid, id]);
  await database.run('DELETE FROM entries WHERE id = ? AND group_id = ?', [eid, id]);

  // Deleting an attendance can invalidate an already-counted streak day —
  // replay the streak from scratch for that user.
  if (entry && (entry.type === 'attend' || (entry.type || 'late') === 'late')) {
    const dbUser = await database.one(
      'SELECT id, streak, freezes, last_streak_date, avail_days, last_freeze_grant, created_at FROM users WHERE group_id = ? AND LOWER(name) = LOWER(?)',
      [id, entry.person]
    );
    if (dbUser && dbUser.last_streak_date && entry.date <= dbUser.last_streak_date) {
      const g = await database.one('SELECT gym_days FROM `groups` WHERE id = ?', [id]);
      const userEntries = await database.all(
        'SELECT date, type FROM entries WHERE group_id = ? AND LOWER(person) = LOWER(?)',
        [id, entry.person]
      );
      await recomputeStreak(dbUser.id, g.gym_days, userEntries, dbUser, true);
    }
  }

  res.json({ ok: true });
}));

// ── Push scheduler (time-based: reminder + streak-at-risk) ──────────────────
setInterval(async () => {
  if (!webpush && !apnProvider) return;
  try {
    const today = dateYMD(new Date());
    const usersWithSubs = await database.all(`
      SELECT DISTINCT u.id, u.group_id, u.name, u.avail_days,
             u.notif_reminders, u.notif_streak, u.reminder_time,
             u.quiet_start, u.quiet_end, u.timezone
      FROM users u
      WHERE u.id IN (SELECT user_id FROM push_subscriptions UNION SELECT user_id FROM apns_tokens)
    `);
    for (const u of usersWithSubs) {
      if (isInQuietHours(u)) continue;
      const g = await database.one('SELECT gym_days FROM `groups` WHERE id = ?', [u.group_id]);
      if (!g) continue;
      const mask = effectiveMask(g.gym_days, u.avail_days);
      if (!isDayScheduled(today, mask)) continue;

      // Gym day reminder
      if (Number(u.notif_reminders) && isTimeNow(u.reminder_time || '09:00', u.timezone)) {
        const already = await database.one(
          'SELECT 1 AS x FROM push_log WHERE user_id = ? AND group_id = ? AND type = ? AND sent_date = ?',
          [u.id, u.group_id, 'reminder', today]
        );
        if (!already) {
          await sendPushToUser(u.id, u.group_id, { title: '💪 Gym day!', body: "Don't forget to check in today", tag: `reminder-${today}` });
          await database.run('INSERT INTO push_log (id,user_id,group_id,type,sent_date) VALUES (?,?,?,?,?)',
            [crypto.randomUUID(), u.id, u.group_id, 'reminder', today]);
        }
      }

      // Streak at risk (1h before quiet start, or 21:00)
      const riskTime = u.quiet_start ? subtractOneHour(u.quiet_start) : '21:00';
      if (Number(u.notif_streak) && isTimeNow(riskTime, u.timezone)) {
        const already = await database.one(
          'SELECT 1 AS x FROM push_log WHERE user_id = ? AND group_id = ? AND type = ? AND sent_date = ?',
          [u.id, u.group_id, 'streak_risk', today]
        );
        if (!already) {
          const checkedIn = await database.one(
            `SELECT 1 AS x FROM entries WHERE group_id = ? AND LOWER(person) = LOWER(?) AND date = ? AND type IN ('attend','late')`,
            [u.group_id, u.name, today]
          );
          if (!checkedIn) {
            await sendPushToUser(u.id, u.group_id, { title: '🔥 Streak at risk!', body: 'Check in today to keep your streak alive', tag: `streak-${today}` });
            await database.run('INSERT INTO push_log (id,user_id,group_id,type,sent_date) VALUES (?,?,?,?,?)',
              [crypto.randomUUID(), u.id, u.group_id, 'streak_risk', today]);
          }
        }
      }
    }
  } catch (e) { console.error('push scheduler:', e); }
}, 60000);

app.use(express.static(__dirname));

app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  if (err.type === 'entity.parse.failed' || err.type === 'entity.too.large') {
    return res.status(400).json({ error: 'bad_request' });
  }
  console.error(err);
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
