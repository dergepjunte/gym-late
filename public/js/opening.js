// ════════════════════════════════════════════════════════
//  DAILY HYPE
// ════════════════════════════════════════════════════════
function shouldShowDailyHype() {
  const today = todayStr();
  if (localStorage.getItem('gymDailyHypeSeen_' + today)) return false;
  return calDayScheduled(today, data?.gymDays || '0000000');
}

function updateDailyHypeTimeUI() {
  const picker = document.getElementById('dh-time-picker');
  const displayEl = document.getElementById('dh-time-display');
  const today = todayStr();
  const enabled = !!data?.fixedCheckinEnabled;
  const hasTimeToday = enabled && data?.checkinTimeDate === today && !!data?.checkinTime;
  picker.classList.toggle('hidden', !enabled || hasTimeToday);
  displayEl.classList.toggle('hidden', !hasTimeToday);
  if (hasTimeToday) document.getElementById('dh-time-display-val').textContent = data.checkinTime;
}

function showDailyHype(force = false) {
  const el = document.getElementById('daily-hype');
  updateDailyHypeTimeUI();
  el.classList.remove('hidden');
  if (!force) localStorage.setItem('gymDailyHypeSeen_' + todayStr(), '1');
}

document.getElementById('dh-close').addEventListener('click', () => {
  document.getElementById('daily-hype').classList.add('hidden');
});

document.getElementById('dh-time-save').addEventListener('click', async () => {
  const val = document.getElementById('dh-time-input').value;
  if (!val) return;
  const btn = document.getElementById('dh-time-save');
  btn.disabled = true;
  try {
    await api.setCheckinTime(data.id, { date: todayStr(), time: val });
    await refresh();
    updateDailyHypeTimeUI();
  } catch { showToast(T.errServer); }
  finally { btn.disabled = false; }
});

// ════════════════════════════════════════════════════════
//  GEO CHECK-IN PROMPT
// ════════════════════════════════════════════════════════
function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Earth radius in meters
  const φ1 = lat1 * Math.PI / 180, φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(Δφ/2)**2 + Math.cos(φ1)*Math.cos(φ2)*Math.sin(Δλ/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function showGeoPrompt() {
  const isGymDay = calDayScheduled(todayStr(), data?.gymDays || '0000000');
  document.getElementById('gp-icon').textContent = isGymDay ? '📍' : '🚫';
  document.getElementById('gp-title').textContent = isGymDay ? T.gpTitle : T.gpNoGymDayTitle;
  document.getElementById('gp-sub').textContent = isGymDay ? T.gpSub : T.gpNoGymDaySub;
  document.getElementById('gp-btns-gymday').classList.toggle('hidden', !isGymDay);
  document.getElementById('gp-btns-nogymday').classList.toggle('hidden', isGymDay);
  document.getElementById('geo-prompt').classList.remove('hidden');
  localStorage.setItem('gymGeoPromptSeen_' + todayStr(), '1');
}

function checkGeoAndPrompt(force = false) {
  if (!data?.gymLat || !data?.gymLng) return; // no location set
  if (!force && localStorage.getItem('gymGeoEnabled') === '0') return; // user disabled
  if (!force) {
    const today = todayStr();
    if (localStorage.getItem('gymGeoPromptSeen_' + today)) return;
    // Don't prompt if already checked in today
    const alreadyIn = (data?.entries||[]).some(e => {
      const me = userProfile?.name;
      return me && e.person === me && e.date === today && (e.type === 'attend' || e.type === 'late');
    });
    if (alreadyIn) return;
  }
  if (!navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition(pos => {
    const dist = haversineMeters(pos.coords.latitude, pos.coords.longitude, data.gymLat, data.gymLng);
    const radius = data.gymRadius ?? 150;
    if (dist <= radius || force) {
      showGeoPrompt();
    }
  }, () => { /* permission denied or error — silently skip */ }, { timeout: 6000, maximumAge: 30000 });
}

document.getElementById('gp-later').addEventListener('click', () => {
  document.getElementById('geo-prompt').classList.add('hidden');
});
document.getElementById('gp-later2').addEventListener('click', () => {
  document.getElementById('geo-prompt').classList.add('hidden');
});

document.getElementById('gp-checkin').addEventListener('click', async () => {
  document.getElementById('geo-prompt').classList.add('hidden');
  await submitSelfAttendEntry();
});

document.getElementById('gp-log-checkin').addEventListener('click', async () => {
  document.getElementById('geo-prompt').classList.add('hidden');
  await submitSelfAttendEntry();
});

// ════════════════════════════════════════════════════════
//  NOTIFICATION BUBBLE SYSTEM
// ════════════════════════════════════════════════════════
let _bubbleQueue = [];
let _pendingBubbleKind = null;
let _replayHintTimer = null;

function _showNotifBubble({ glyph, t1, t2, kind }) {
  _pendingBubbleKind = kind;
  document.getElementById('notif-glyph').textContent = glyph;
  document.getElementById('notif-t1').textContent = t1;
  document.getElementById('notif-t2').textContent = t2;
  const el = document.getElementById('notif-bubble');
  el.classList.add('show');
}

function _dismissNotifBubble() {
  document.getElementById('notif-bubble').classList.remove('show');
  _pendingBubbleKind = null;
}

function _advanceBubbleQueue() {
  if (_bubbleQueue.length === 0) {
    checkGeoAndPrompt();
    return;
  }
  const b = _bubbleQueue.shift();
  setTimeout(() => _showNotifBubble(b), 120);
}

function _showReplayHint(kind) {
  const el = document.getElementById('replay-hint');
  const isRecap = kind === 'wrapped';
  el.textContent = isRecap ? T.replayHintRecap : T.replayHintCheckin;
  el.style.display = '';
  el.onclick = isRecap ? () => {
    el.classList.remove('show');
    setTimeout(() => { el.style.display = 'none'; }, 250);
    switchTab('recap');
  } : null;
  requestAnimationFrame(() => el.classList.add('show'));
  clearTimeout(_replayHintTimer);
  _replayHintTimer = setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => { el.style.display = 'none'; }, 250);
  }, 6000);
}

// Bubble tap/dismiss wiring
document.getElementById('notif-bubble').addEventListener('click', e => {
  if (!_pendingBubbleKind) return;
  if (e.target.id === 'notif-x' || e.target.closest('#notif-x')) {
    // Dismiss → show hint, advance queue
    const kind = _pendingBubbleKind;
    _dismissNotifBubble();
    _showReplayHint(kind);
    _advanceBubbleQueue();
  } else {
    // Tap → play full animation
    const kind = _pendingBubbleKind;
    _dismissNotifBubble();
    if (kind === 'wrapped') showWrapped();
    else if (kind === 'hype') showDailyHype();
    else if (kind === 'geo') showGeoPrompt();
    _advanceBubbleQueue();
  }
});

// ════════════════════════════════════════════════════════
//  OPENING SEQUENCE (Wrapped → Daily Hype → Geo Prompt)
// ════════════════════════════════════════════════════════
function runOpeningSequence() {
  _bubbleQueue = [];
  if (shouldShowWrapped()) {
    _bubbleQueue.push({ glyph: '🎉', t1: T.bubbleWrappedTitle, t2: T.bubbleWrappedSub, kind: 'wrapped' });
  }
  if (shouldShowDailyHype()) {
    _bubbleQueue.push({ glyph: '💪', t1: T.bubbleHypeTitle, t2: T.bubbleHypeSub, kind: 'hype' });
  }
  if (!_bubbleQueue.length) { checkGeoAndPrompt(); return; }
  setTimeout(_advanceBubbleQueue, 600);
}

