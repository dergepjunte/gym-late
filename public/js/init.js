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
  showFsOverlay('notif-primer');
}

document.getElementById('notif-primer-enable').addEventListener('click', async () => {
  localStorage.setItem('gymNotifPrimerSeen', '1');
  hideFsOverlay('notif-primer');
  await initPush().catch(() => {});
});

document.getElementById('notif-primer-later').addEventListener('click', () => {
  localStorage.setItem('gymNotifPrimerSeen', '1');
  hideFsOverlay('notif-primer');
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

function init() {
  // group/userProfile stay unset until a profile card is actually picked —
  // switchToGroup() no-ops if the tapped group already matches the active `group`
  let all = loadAllGroups();
  if (all.length === 0) {
    // Backfill the multi-group registry from a pre-multi-group install
    try {
      const legacy = JSON.parse(localStorage.getItem('gymGroup') || 'null');
      if (legacy) { saveAllGroups([legacy]); all = [legacy]; }
    } catch {}
  }
  showLoading(false);
  if (all.length > 0) {
    renderProfilePicker();
    showScreen('profile-picker');
    return;
  }
  showScreen('landing');
}
init();
