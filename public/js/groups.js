// ════════════════════════════════════════════════════════
//  GROUP SWITCHER
// ════════════════════════════════════════════════════════
async function switchToGroup(g) {
  if (group && g.id === group.id) return;
  // Save current group's user profile separately, then switch
  stopPolling();
  loadUser(g.id);
  try {
    showLoading(true);
    const newData = await api.getGroup(g.id);
    group = g;
    localStorage.setItem('gymGroup', JSON.stringify(g));
    data = newData;
    // If no user profile for this group, open profile setup
    if (!userProfile) {
      pendingGroup = g;
      showLoading(false); applyI18n(); showScreen('landing'); openProfileSetup();
      return;
    }
    const me = data.people.find(p => p.id === userProfile.userId);
    if (!me) {
      clearUser(g.id); userProfile = null;
      showLoading(false); showScreen('landing');
      setTimeout(() => showToast(T.kicked), 300); return;
    }
    userProfile.isCreator = me.isCreator;
    saveUser(g.id, userProfile);
    showLoading(false);
    updateMyProfileBtn(); applyI18n(); renderAll(); startPolling(); showScreen('app');
    showToast(g.name);
  } catch { showLoading(false); showToast(T.errServer); }
}

function buildGroupListHTML(all) {
  return all.map(g => {
    const isActive = group && g.id === group.id;
    return `<div class="group-list-item" data-gid="${esc(g.id)}">
      <div class="group-list-icon">🏋️</div>
      <div style="flex:1;min-width:0">
        <div class="group-list-name">${esc(g.name)}</div>
        <div class="group-list-code">${esc(g.code)}</div>
      </div>
      ${isActive ? `<span class="group-list-active">${T.mgsActive}</span>` : `<span class="group-list-active" style="color:var(--text-3)">${T.mgsSwitch}</span>`}
    </div>`;
  }).join('');
}

function openGroupSwitcher() {
  const all = loadAllGroups();
  const listEl = document.getElementById('mgs-list');
  listEl.innerHTML = buildGroupListHTML(all);
  listEl.querySelectorAll('.group-list-item').forEach(el => {
    el.addEventListener('click', () => {
      const g = all.find(x => x.id === el.dataset.gid);
      closePage('modal-group-switcher');
      if (g) switchToGroup(g);
    });
  });
  openPage('modal-group-switcher');
}

// Inline groups section in the People tab
function renderGroupsSection() {
  const all = loadAllGroups();
  const listEl = document.getElementById('groups-list');
  if (!listEl) return;
  listEl.innerHTML = buildGroupListHTML(all);
  listEl.querySelectorAll('.group-list-item').forEach(el => {
    el.addEventListener('click', () => {
      const g = all.find(x => x.id === el.dataset.gid);
      if (g) switchToGroup(g);
    });
  });
}

document.getElementById('mgs-close-btn').addEventListener('click', () => closePage('modal-group-switcher'));

document.getElementById('mgs-join-btn').addEventListener('click', () => {
  closePage('modal-group-switcher');
  stopPolling();
  showScreen('landing');
  setTimeout(() => openPage('modal-join'), 200);
});
document.getElementById('mgs-create-btn').addEventListener('click', () => {
  closePage('modal-group-switcher');
  stopPolling();
  showScreen('landing');
  setTimeout(() => openPage('modal-create'), 200);
});

// Inline join/create from the People tab
document.getElementById('pp-join-btn').addEventListener('click', () => {
  stopPolling();
  showScreen('landing');
  setTimeout(() => openPage('modal-join'), 200);
});
document.getElementById('pp-create-btn').addEventListener('click', () => {
  stopPolling();
  showScreen('landing');
  setTimeout(() => openPage('modal-create'), 200);
});

document.getElementById('leave-btn').addEventListener('click',()=>{
  if (!confirm(T.confirmLeave())) return;
  stopPolling(); exitAdmin();
  if (group) clearUser(group.id);
  clearGroup();
  const remaining = loadAllGroups();
  if (remaining.length > 0) {
    // Switch to the first remaining group
    const g = remaining[0];
    group = g;
    localStorage.setItem('gymGroup', JSON.stringify(g));
    loadUser(g.id);
    showLoading(true);
    api.getGroup(g.id).then(d => {
      data = d;
      showLoading(false); applyI18n(); renderAll(); startPolling(); showScreen('app');
      showToast(g.name);
    }).catch(() => { showLoading(false); showScreen('landing'); });
  } else {
    showScreen('landing');
  }
});

document.getElementById('invite-btn').addEventListener('click', () => {
  if (!data) return;
  copyToClipboard(data.code);
});

document.addEventListener('click', async e => {
  const edb = e.target.closest('.edit-entry-btn');
  if (edb && data) { openEditEntry(edb.dataset.id); return; }
  const eb = e.target.closest('.del-entry-btn');
  if (eb && data) { try{await api.delEntry(data.id,eb.dataset.id,adminPassword); await refresh();}catch{showToast(T.errServer);} return; }
  // Tap on person row → open profile or admin-edit (when admin)
  const pr = e.target.closest('.person-row[data-uid]');
  if (pr && data) {
    if (adminMode && adminPassword) {
      const uid = pr.dataset.uid;
      const isMe = userProfile?.userId === uid;
      if (!isMe) { openAdminUserEdit(uid); return; }
    }
    openProfileView(pr.dataset.uid);
    return;
  }
});

