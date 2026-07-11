// ════════════════════════════════════════════════════════
//  INIT
// ════════════════════════════════════════════════════════
applyI18n();
// ── Push notification (web) ──────────────────────────────────────────────────

// Show the primer once; if already seen, call initPush() directly.
function maybeShowNotifPrimer() {
  if (localStorage.getItem('gymNotifPrimerSeen')) {
    initPush().catch(() => {});
    return;
  }
  const el = document.getElementById('notif-primer');
  if (el) el.classList.remove('hidden');
}

document.getElementById('notif-primer-enable').addEventListener('click', async () => {
  localStorage.setItem('gymNotifPrimerSeen', '1');
  document.getElementById('notif-primer').classList.add('hidden');
  await initPush().catch(() => {});
});

document.getElementById('notif-primer-later').addEventListener('click', () => {
  localStorage.setItem('gymNotifPrimerSeen', '1');
  document.getElementById('notif-primer').classList.add('hidden');
});

async function initPush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
  if (!userProfile || !group) return;
  const reg = await navigator.serviceWorker.register('/sw.js');
  await navigator.serviceWorker.ready;

  let keyRes;
  try { keyRes = await fetch('/api/push/vapid-public-key'); } catch { return; }
  if (!keyRes.ok) return;
  const { key } = await keyRes.json();

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return;

  const existing = await reg.pushManager.getSubscription();
  const sub = existing || await reg.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(key),
  });

  await fetch('/api/push/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: userProfile.userId,
      groupId: group.id,
      recoveryCode: userProfile.recoveryCode,
      subscription: sub.toJSON(),
    }),
  });

  // Sync stored notification preferences to server
  const prefs = loadNotifPrefs();
  await saveNotifPrefsToServer(prefs).catch(() => {});
}

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}

function loadNotifPrefs() {
  try { return JSON.parse(localStorage.getItem('gymNotifPrefs') || '{}'); } catch { return {}; }
}

function saveNotifPrefs(prefs) {
  localStorage.setItem('gymNotifPrefs', JSON.stringify(prefs));
}

async function saveNotifPrefsToServer(prefs) {
  if (!userProfile || !group) return;
  await fetch(`/api/groups/${group.id}/users/${userProfile.userId}/notif`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ recoveryCode: userProfile.recoveryCode, ...prefs }),
  });
}

async function init() {
  showLoading(true); loadGroup();
  if (group) {
    loadUser(group.id);
    try {
      data = await api.getGroup(group.id);
    } catch(e) {
      if (e.status===404) clearGroup();
      showLoading(false); showScreen('landing'); return;
    }
    if (!userProfile) {
      // Stored group but no user — show profile setup
      showLoading(false);
      pendingGroup = group;
      applyI18n(); showScreen('landing'); openProfileSetup();
      return;
    }
    // Check if user is still in the group (not kicked)
    const me = data.people.find(p => p.id === userProfile.userId);
    if (!me) {
      clearUser(group.id); userProfile = null;
      showLoading(false); showScreen('landing');
      setTimeout(() => showToast(T.kicked), 300); return;
    }
    userProfile.isCreator = me.isCreator;
    if ('avatarImg' in me) userProfile.avatarImg = me.avatarImg;
    saveUser(group.id, userProfile);
    updateMyProfileBtn();
    applyI18n(); renderAll(); startPolling(); showLoading(false); showScreen('app');
    runOpeningSequence();
    maybeShowNotifPrimer();
    return;
  }
  showLoading(false); showScreen('landing');
}
init();
