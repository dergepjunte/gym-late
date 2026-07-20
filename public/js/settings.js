// ════════════════════════════════════════════════════════
//  SETTINGS MODAL
// ════════════════════════════════════════════════════════
function formatDuration(ms) {
  const h = Math.floor(ms / 3600000), m = Math.floor((ms % 3600000) / 60000), d = Math.floor(ms / 86400000);
  if (d >= 1) return `${d}d ${h % 24}h`;
  return `${h}h ${m}m`;
}

let _leafletMap = null, _leafletMarker = null, _leafletCircle = null;

function openSettings() {
  if (!data) return;
  const gymDays = data.gymDays || '1111100';
  const me = data.people.find(p => userProfile && p.id === userProfile.userId);
  const availDays = me?.availDays || gymDays;
  const availEditedAt = me?.availEditedAt || null;
  const isCreator = userProfile?.isCreator;
  const canEditGroup = isCreator || adminMode;

  // Gym days section (creator or admin)
  const gymSection = document.getElementById('mset-gymdays-section');
  gymSection.style.display = canEditGroup ? '' : 'none';
  if (canEditGroup) {
    buildDayPicker('mset-gym-picker', gymDays);
    document.getElementById('mset-gym-error').textContent = '';
  }

  // Fixed check-in time (Beta, creator or admin)
  const fixedSection = document.getElementById('mset-fixedtime-section');
  fixedSection.classList.toggle('hidden', !canEditGroup);
  if (canEditGroup) {
    document.getElementById('mset-fixedtime-toggle').checked = !!data?.fixedCheckinEnabled;
    document.getElementById('mset-fixedtime-hint').textContent = '';
  }

  // Gym location section (creator or admin)
  const mapSection = document.getElementById('mset-map-section');
  mapSection.classList.toggle('hidden', !canEditGroup);
  // Leaflet map is initialized lazily by selectSettingsTab() once the Group tab is actually visible

  // Avail days (current user, within gym days mask)
  buildDayPicker('mset-avail-picker', availDays, gymDays);

  // Lock check
  const lockEl = document.getElementById('mset-avail-lock');
  const saveBtn = document.getElementById('mset-avail-save');
  const LOCK_OPEN_MS = 3600000, LOCK_DURATION_MS = 30 * 86400000;
  if (availEditedAt) {
    const elapsed = Date.now() - availEditedAt;
    if (elapsed > LOCK_OPEN_MS && elapsed < LOCK_DURATION_MS) {
      const remaining = LOCK_DURATION_MS - elapsed;
      lockEl.textContent = T.availLocked(formatDuration(remaining));
      lockEl.classList.remove('hidden');
      saveBtn.disabled = true;
    } else {
      lockEl.classList.add('hidden');
      saveBtn.disabled = false;
    }
  } else {
    lockEl.classList.add('hidden');
    saveBtn.disabled = false;
  }
  document.getElementById('mset-avail-error').textContent = '';

  // Launch loading animation style
  const loadingStyle = localStorage.getItem('gymLoadingStyle') || 'barbell';
  document.querySelectorAll('#mset-loadstyle-picker .loadstyle-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.style === loadingStyle);
  });

  // Geo toggle — visible to all users
  const geoEnabled = localStorage.getItem('gymGeoEnabled') !== '0';
  document.getElementById('mset-geo-toggle').checked = geoEnabled;
  document.getElementById('mset-geo-hint').textContent = '';
  // Show geo section only if gym location is set
  document.getElementById('mset-geo-section').style.display = data?.gymLat ? '' : 'none';
  document.getElementById('mset-leave-btn').textContent = T.leaveGroup;

  // Notification preferences
  const prefs = loadNotifPrefs();
  document.getElementById('mset-notif-reminders').checked = prefs.notifReminders !== false;
  document.getElementById('mset-reminder-time').value = prefs.reminderTime || '09:00';
  document.getElementById('mset-notif-streak').checked = prefs.notifStreak !== false;
  document.getElementById('mset-notif-activity').checked = prefs.notifActivity !== false;
  document.getElementById('mset-quiet-start').value = prefs.quietStart || '22:00';
  document.getElementById('mset-quiet-end').value = prefs.quietEnd || '08:00';
  // Member filter list
  const membersList = document.getElementById('mset-notif-members-list');
  membersList.innerHTML = '';
  const notifMembers = prefs.notifMembers || null; // null = everyone
  if (data?.people) {
    for (const p of data.people) {
      if (userProfile && p.id === userProfile.userId) continue;
      const row = document.createElement('label');
      row.className = 'notif-member-row';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.value = p.id;
      cb.checked = !notifMembers || notifMembers.includes(p.id);
      const name = document.createElement('span');
      name.className = 'notif-member-name';
      name.textContent = p.name;
      row.appendChild(cb); row.appendChild(name);
      membersList.appendChild(row);
    }
  }
  // Account & Login
  const acc = loadAccount();
  document.getElementById('mset-account-lbl').textContent = T.mgAccountSectionLbl;
  document.getElementById('mset-account-nolink').style.display = acc ? 'none' : '';
  document.getElementById('mset-account-linked').style.display = acc ? '' : 'none';
  if (acc) {
    document.getElementById('mset-account-email').textContent = acc.email || '';
  } else {
    document.getElementById('mset-account-hint').textContent = T.migSub;
    document.getElementById('mset-account-secure-btn').textContent = T.migSetPw;
  }
  document.getElementById('mset-account-signout-btn').textContent = T.mgAccountSignOut;

  // Tabs — Group hidden for non-creators, Notify hidden without push support
  const notifSupported = ('Notification' in window);
  document.getElementById('mset-tab-group').classList.toggle('hidden', !canEditGroup);
  document.getElementById('mset-tab-notify').classList.toggle('hidden', !notifSupported);
  let targetTab = currentSettingsTab;
  if (targetTab === 'group' && !canEditGroup) targetTab = 'you';
  if (targetTab === 'notify' && !notifSupported) targetTab = 'you';
  selectSettingsTab(targetTab);

  openPage('modal-settings');
}

// ── Settings tabs (You / Group / Notify / Account) ──
let currentSettingsTab = 'you';

function selectSettingsTab(tab) {
  currentSettingsTab = tab;
  document.querySelectorAll('#mset-tabs .settings-tab').forEach(btn => {
    btn.classList.toggle('sel', btn.dataset.tab === tab);
  });
  document.querySelectorAll('.settings-panel').forEach(panel => {
    panel.classList.toggle('hidden', panel.dataset.panel !== tab);
  });
  // Leaflet needs a visible container to size itself correctly — (re)init once the Group tab is shown
  if (tab === 'group') {
    setTimeout(() => { initLeafletMap(); setTimeout(() => _leafletMap && _leafletMap.invalidateSize(), 80); }, 50);
  }
}

document.getElementById('mset-tabs').addEventListener('click', e => {
  const btn = e.target.closest('.settings-tab');
  if (!btn || btn.classList.contains('hidden')) return;
  selectSettingsTab(btn.dataset.tab);
});

document.getElementById('mset-account-secure-btn').addEventListener('click', () => {
  closePage('modal-settings');
  openAccountAuth('register', 'migrate');
});
document.getElementById('mset-account-signout-btn').addEventListener('click', () => {
  clearAccount();
  closePage('modal-settings');
  showToast(T.mgAccountSignedOut);
});

document.getElementById('mset-close').addEventListener('click', () => closePage('modal-settings'));
document.getElementById('mset-leave-btn').addEventListener('click', () => {
  if (!confirm(T.confirmLeave())) return;
  closePage('modal-settings');
  document.getElementById('leave-btn').click();
});

document.getElementById('mset-geo-toggle').addEventListener('change', e => {
  localStorage.setItem('gymGeoEnabled', e.target.checked ? '1' : '0');
});

document.querySelectorAll('#mset-loadstyle-picker .loadstyle-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    localStorage.setItem('gymLoadingStyle', btn.dataset.style);
    document.querySelectorAll('#mset-loadstyle-picker .loadstyle-btn').forEach(b => b.classList.toggle('active', b === btn));
  });
});

document.getElementById('mset-notif-save').addEventListener('click', async () => {
  const checkedMembers = [...document.querySelectorAll('#mset-notif-members-list input[type=checkbox]')]
    .filter(cb => cb.checked).map(cb => cb.value);
  const totalMembers = document.querySelectorAll('#mset-notif-members-list input[type=checkbox]').length;
  const notifMembers = checkedMembers.length === totalMembers ? null : checkedMembers;
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const prefs = {
    notifReminders: document.getElementById('mset-notif-reminders').checked,
    reminderTime: document.getElementById('mset-reminder-time').value || '09:00',
    notifStreak: document.getElementById('mset-notif-streak').checked,
    notifActivity: document.getElementById('mset-notif-activity').checked,
    quietStart: document.getElementById('mset-quiet-start').value || '22:00',
    quietEnd: document.getElementById('mset-quiet-end').value || '08:00',
    notifMembers,
    timezone,
  };
  saveNotifPrefs(prefs);
  try {
    await saveNotifPrefsToServer(prefs);
    showToast(T.toastNotifSaved);
  } catch { showToast(T.errServer); }
});

document.getElementById('mset-fixedtime-toggle').addEventListener('change', async e => {
  const checked = e.target.checked;
  const hintEl = document.getElementById('mset-fixedtime-hint');
  e.target.disabled = true;
  try {
    const body = adminMode && adminPassword
      ? { adminPassword, fixed_checkin_enabled: checked }
      : { creatorUserId: userProfile.userId, creatorRecoveryCode: userProfile.recoveryCode, fixed_checkin_enabled: checked };
    await api.patchGroup(data.id, body);
    hintEl.textContent = '';
    showToast(checked ? T.toastFixedCheckinOn : T.toastFixedCheckinOff);
    await refresh();
  } catch {
    e.target.checked = !checked;
    hintEl.textContent = T.errServer;
  } finally {
    e.target.disabled = false;
  }
});

document.getElementById('mset-geo-test').addEventListener('click', () => {
  const hintEl = document.getElementById('mset-geo-hint');
  if (!data?.gymLat || !data?.gymLng) { hintEl.textContent = T.msetGeoNoLoc; return; }
  if (!navigator.geolocation) { hintEl.textContent = T.errGeoNotAvailable; return; }
  hintEl.textContent = '…';
  navigator.geolocation.getCurrentPosition(pos => {
    const dist = haversineMeters(pos.coords.latitude, pos.coords.longitude, data.gymLat, data.gymLng);
    const radius = data.gymRadius ?? 150;
    hintEl.textContent = `${Math.round(dist)}m (Radius: ${radius}m)`;
    if (dist <= radius) {
      closePage('modal-settings');
      showGeoPrompt();
    }
  }, () => { hintEl.textContent = T.errLocationNotAvailable; }, { timeout: 8000 });
});

document.getElementById('mset-gym-save').addEventListener('click', async () => {
  const gymDays = getDayMask('mset-gym-picker');
  if (!gymDays.includes('1')) { document.getElementById('mset-gym-error').textContent = T.errAtLeastOneDay; return; }
  const btn = document.getElementById('mset-gym-save');
  btn.disabled = true;
  try {
    const body = adminMode && adminPassword
      ? { adminPassword, gym_days: gymDays }
      : { creatorUserId: userProfile.userId, creatorRecoveryCode: userProfile.recoveryCode, gym_days: gymDays };
    await api.patchGroup(data.id, body);
    showToast(T.toastGymDaysSaved);
    await refresh();
    closePage('modal-settings');
  } catch { document.getElementById('mset-gym-error').textContent = T.errServer; }
  finally { btn.disabled = false; }
});

document.getElementById('mset-avail-save').addEventListener('click', async () => {
  const availDays = getDayMask('mset-avail-picker');
  const btn = document.getElementById('mset-avail-save');
  btn.disabled = true;
  try {
    await api.updateUser(data.id, userProfile.userId, {
      recoveryCode: userProfile.recoveryCode,
      avail_days: availDays
    });
    showToast(T.toastAvailSaved);
    await refresh();
    closePage('modal-settings');
  } catch(e) {
    document.getElementById('mset-avail-error').textContent = e.status === 403 ? T.errAvailLocked : T.errServer;
  }
  finally { btn.disabled = false; }
});

// ════════════════════════════════════════════════════════
//  ADMIN USER EDIT MODAL
// ════════════════════════════════════════════════════════
let editingAdminUserId = null;

function openAdminUserEdit(userId) {
  if (!adminMode || !adminPassword) return;
  editingAdminUserId = userId;
  const user = data?.people?.find(p => p.id === userId);
  if (!user) return;

  document.getElementById('au-title').textContent = T.auTitle(user.name);
  buildDayPicker('au-day-picker', user.availDays || data.gymDays || '1111100');
  document.getElementById('au-streak-input').value  = user.streak  ?? 0;
  document.getElementById('au-freezes-input').value = user.freezes ?? 0;
  document.getElementById('au-error').textContent = '';
  openPage('modal-admin-user');
}

document.getElementById('au-cancel').addEventListener('click', () => closePage('modal-admin-user'));

document.getElementById('au-save').addEventListener('click', async () => {
  if (!editingAdminUserId) return;
  const btn = document.getElementById('au-save');
  btn.disabled = true;
  document.getElementById('au-error').textContent = '';
  try {
    const avail_days = getDayMask('au-day-picker');
    const streak  = Number(document.getElementById('au-streak-input').value);
    const freezes = Number(document.getElementById('au-freezes-input').value);
    await api.updateUser(data.id, editingAdminUserId, {
      adminPassword,
      avail_days,
      streak,
      freezes
    });
    closePage('modal-admin-user');
    await refresh();
    showToast(T.toastMemberUpdated);
  } catch { document.getElementById('au-error').textContent = T.errServer; }
  finally { btn.disabled = false; }
});

document.getElementById('au-kick-btn').addEventListener('click', async () => {
  const user = data?.people?.find(p => p.id === editingAdminUserId);
  if (!user || !confirm(T.pvKickConfirm(user.name))) return;
  try {
    await api.kickUser(data.id, editingAdminUserId, { adminPassword });
    closePage('modal-admin-user');
    await refresh();
    showToast(T.toastKicked);
  } catch { showToast(T.errServer); }
});

// ════════════════════════════════════════════════════════
//  LEAFLET MAP (GYM LOCATION)
// ════════════════════════════════════════════════════════
function initLeafletMap() {
  if (typeof L === 'undefined') return; // Leaflet not loaded
  const container = document.getElementById('mset-map-container');
  if (!container) return;

  const defaultLat = data?.gymLat ?? 48.137;
  const defaultLng = data?.gymLng ?? 11.576;
  const defaultRadius = data?.gymRadius ?? 150;

  document.getElementById('mset-radius-slider').value = defaultRadius;
  document.getElementById('mset-radius-val').textContent = defaultRadius + 'm';

  if (_leafletMap) {
    _leafletMap.setView([defaultLat, defaultLng], 15);
    _leafletMarker.setLatLng([defaultLat, defaultLng]);
    _leafletCircle.setLatLng([defaultLat, defaultLng]).setRadius(defaultRadius);
    _leafletMap.invalidateSize();
    return;
  }

  _leafletMap = L.map(container, { zoomControl: true }).setView([defaultLat, defaultLng], 15);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap'
  }).addTo(_leafletMap);

  _leafletMarker = L.marker([defaultLat, defaultLng], { draggable: true }).addTo(_leafletMap);
  _leafletCircle = L.circle([defaultLat, defaultLng], { radius: defaultRadius, color: '#7c3aed', fillOpacity: 0.15 }).addTo(_leafletMap);

  _leafletMarker.on('dragend', () => {
    const ll = _leafletMarker.getLatLng();
    _leafletCircle.setLatLng(ll);
  });

  const slider = document.getElementById('mset-radius-slider');
  const valEl  = document.getElementById('mset-radius-val');
  slider.addEventListener('input', () => {
    valEl.textContent = slider.value + 'm';
    _leafletCircle.setRadius(Number(slider.value));
  });

  setTimeout(() => _leafletMap && _leafletMap.invalidateSize(), 100);
}

document.getElementById('mset-locate-btn').addEventListener('click', () => {
  if (!navigator.geolocation) { showToast(T.errGeoNotAvailable); return; }
  navigator.geolocation.getCurrentPosition(pos => {
    if (!_leafletMap) return;
    const ll = [pos.coords.latitude, pos.coords.longitude];
    _leafletMap.setView(ll, 16);
    _leafletMarker.setLatLng(ll);
    _leafletCircle.setLatLng(ll);
  }, () => showToast(T.errLocationNotAvailable));
});

document.getElementById('mset-location-save').addEventListener('click', async () => {
  if (!_leafletMarker) { showToast(T.errMapNotLoaded); return; }
  const ll = _leafletMarker.getLatLng();
  const radius = Number(document.getElementById('mset-radius-slider').value);
  const btn = document.getElementById('mset-location-save');
  btn.disabled = true;
  try {
    const base = adminMode && adminPassword
      ? { adminPassword }
      : { creatorUserId: userProfile.userId, creatorRecoveryCode: userProfile.recoveryCode };
    await api.patchGroup(data.id, { ...base, gym_lat: ll.lat, gym_lng: ll.lng, gym_radius: radius });
    showToast(T.toastLocationSaved);
    await refresh();
    renderAdminPanel();
    closePage('modal-settings');
  } catch { document.getElementById('mset-location-error').textContent = T.errServer; }
  finally { btn.disabled = false; }
});

