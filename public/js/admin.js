// ════════════════════════════════════════════════════════
//  ADMIN
// ════════════════════════════════════════════════════════
let adminTaps = 0, adminTapTimer;

document.getElementById('header-icon').addEventListener('click', () => {
  if (!group) return;
  adminTaps++;
  clearTimeout(adminTapTimer);
  adminTapTimer = setTimeout(() => { adminTaps = 0; }, 2000);
  if (adminTaps >= 5) {
    adminTaps = 0;
    if (adminMode) { exitAdmin(); } else { openAdminLogin(); }
  }
});

function openAdminLogin() {
  document.getElementById('ma-pwd').value = '';
  document.getElementById('ma-error').textContent = '';
  openPage('modal-admin');
  setTimeout(() => document.getElementById('ma-pwd').focus(), 350);
}

function activateAdmin({ silent = false } = {}) {
  adminMode = true;
  document.getElementById('admin-badge').classList.toggle('hidden', !group);
  if (!silent) showToast(T.toastAdmIn);
  renderLandingAdminTools();
  if (group) {
    renderAdminPanel();
    renderWeek();
    openPage('modal-admin-panel');
  }
}

function exitAdmin() {
  adminMode = false;
  adminShowCurWeek = false;
  adminPassword = '';
  document.getElementById('admin-badge').classList.add('hidden');
  closePage('modal-admin-panel');
  showToast(T.toastAdmOut);
  renderLandingAdminTools(); renderHistory(); renderWeek();
}

document.getElementById('ma-cancel').addEventListener('click', () => closePage('modal-admin'));

document.getElementById('ma-submit').addEventListener('click', async () => {
  const btn = document.getElementById('ma-submit');
  const errEl = document.getElementById('ma-error');
  const pwd = document.getElementById('ma-pwd').value.trim();
  if (!pwd) { errEl.textContent = T.maError; return; }
  btn.disabled = true; errEl.textContent = '';
  try {
    await api.verifyAdmin(pwd);
    closePage('modal-admin');
    adminPassword = pwd;
    activateAdmin();
  } catch {
    errEl.textContent = T.maError;
  } finally {
    btn.disabled = false;
  }
});
document.getElementById('ma-pwd').addEventListener('keydown', e => { if(e.key==='Enter') document.getElementById('ma-submit').click(); });

// Admin panel page navigation
document.getElementById('adm-page-back').addEventListener('click', () => closePage('modal-admin-panel'));
document.getElementById('admin-badge').addEventListener('click', () => { if (adminMode) openPage('modal-admin-panel'); });

// Admin buttons
document.getElementById('adm-exit-btn').addEventListener('click', exitAdmin);
document.getElementById('adm-replay-btn').addEventListener('click', () => {
  _bubbleQueue = [{ glyph: '🎉', t1: T.bubbleWrappedTitle, t2: T.bubbleWrappedSub, kind: 'wrapped' }];
  _advanceBubbleQueue();
});

document.getElementById('adm-week-btn').addEventListener('click', () => {
  adminShowCurWeek = !adminShowCurWeek;
  renderAdminPanel();
  // if recap tab is active, re-render it
  if (document.getElementById('pane-recap').classList.contains('active')) renderHistory();
});

document.getElementById('adm-add-btn').addEventListener('click', async () => {
  if (!data?.people?.length) { showToast(T.noMembersForTest); return; }
  const people   = data.people.map(p => p.name);
  const lastMon  = addDays(mondayOf(todayStr()), -7);
  const schedule = [
    { person: people[0 % people.length], date: addDays(lastMon, 0), mins: 12 },
    { person: people[1 % people.length], date: addDays(lastMon, 1), mins:  5 },
    { person: people[0 % people.length], date: addDays(lastMon, 2), mins: 22 },
    { person: people[2 % people.length], date: addDays(lastMon, 3), mins:  8 },
    { person: people[1 % people.length], date: addDays(lastMon, 4), mins: 17 },
    { person: people[2 % people.length], date: addDays(lastMon, 0), mins: 31 },
  ];
  const ids = [];
  for (const e of schedule) {
    try { const r = await api.addEntry(data.id, e); ids.push(r.id); } catch {}
  }
  testEntryIds = [...testEntryIds, ...ids];
  await refresh();
  showToast(T.toastAdded);
  // Jump to history tab so the user immediately sees the recap
  switchTab('history');
});

document.getElementById('adm-del-btn').addEventListener('click', async () => {
  if (!testEntryIds.length) { showToast(T.noTestData); return; }
  for (const id of testEntryIds) {
    try { await api.delEntry(data.id, id, adminPassword); } catch {}
  }
  testEntryIds = [];
  await refresh();
  showToast(T.toastCleared);
});

// Admin debug buttons — enqueue bubbles so the full flow is testable
document.getElementById('adm-force-hype-btn').addEventListener('click', () => {
  _bubbleQueue = [{ glyph: '💪', t1: T.bubbleHypeTitle, t2: T.bubbleHypeSub, kind: 'hype' }];
  _advanceBubbleQueue();
});
document.getElementById('adm-force-geo-btn').addEventListener('click', () => {
  _bubbleQueue = [{ glyph: '📍', t1: T.bubbleGeoTitle, t2: T.bubbleGeoSub, kind: 'geo' }];
  _advanceBubbleQueue();
});
document.getElementById('adm-clear-flags-btn').addEventListener('click', () => {
  const today = todayStr();
  localStorage.removeItem('gymDailyHypeSeen_' + today);
  localStorage.removeItem('gymGeoPromptSeen_' + today);
  showToast(T.toastCleared);
});

// Test push notifications (10s delay)
async function sendTestPush(type) {
  try {
    await api.testPush(type);
    showToast(T.toastTestScheduled);
  } catch {
    showToast('Push not configured');
  }
}
document.getElementById('adm-test-reminder').addEventListener('click', () => sendTestPush('reminder'));
document.getElementById('adm-test-streak').addEventListener('click', () => sendTestPush('streak'));
document.getElementById('adm-test-activity').addEventListener('click', () => sendTestPush('activity'));
document.getElementById('adm-test-all').addEventListener('click', () => sendTestPush('all'));

