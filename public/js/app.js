// ════════════════════════════════════════════════════════
//  POLLING
// ════════════════════════════════════════════════════════
let _lastRenderKey = null;
async function refresh() {
  if (!group) return;
  try {
    const fresh = await api.getGroup(group.id);
    data = fresh; // always assign — await refresh() callers read fresh data
    // Skip the full DOM rebuild when nothing changed since the last poll.
    // Key includes group id (group switches) and today (midnight rollover).
    const key = group.id + '|' + todayStr() + '|' + JSON.stringify(fresh);
    if (key === _lastRenderKey) return;
    _lastRenderKey = key;
    renderAll();
  } catch(e) {
    if (e.status===404) { clearGroup(); stopPolling(); showScreen('landing'); }
  }
}
function startPolling() { stopPolling(); pollTimer = setInterval(refresh, 8000); }
function stopPolling()  { if (pollTimer) { clearInterval(pollTimer); pollTimer=null; } }

// ════════════════════════════════════════════════════════
//  ENTER GROUP
// ════════════════════════════════════════════════════════
async function enterGroup(g) {
  saveGroup(g);
  showLoading(true);
  try {
    data = await api.getGroup(g.id);
  } catch {
    clearGroup(); showLoading(false); showScreen('landing'); return;
  }
  // Sync isCreator from server (may have changed)
  if (userProfile) {
    const me = data.people.find(p => p.id === userProfile.userId);
    if (!me) {
      clearUser(g.id); userProfile = null;
      showLoading(false); showScreen('landing');
      setTimeout(() => showToast(T.kicked), 300);
      return;
    }
    userProfile.isCreator = me.isCreator;
    if ('avatarImg' in me) userProfile.avatarImg = me.avatarImg;
    saveUser(g.id, userProfile);
  }
  showLoading(false);
  updateMyProfileBtn();
  applyI18n(); renderAll(); startPolling(); showScreen('app');
  runOpeningSequence();
  maybeShowNotifPrimer();
  maybeShowMigrateBanner();
}

function updateMyProfileBtn() {
  const btn = document.getElementById('my-profile-btn');
  if (!userProfile) { btn.classList.remove('visible'); return; }
  btn.classList.add('visible');
  if (userProfile.avatarImg && userProfile.avatarImg.startsWith('data:image/')) {
    btn.textContent = '';
    btn.style.backgroundImage = `url(${userProfile.avatarImg})`;
    btn.style.backgroundSize = 'cover';
    btn.style.backgroundPosition = 'center';
    btn.style.color = 'transparent';
  } else {
    btn.textContent = userProfile.avatarEmoji;
    btn.style.backgroundImage = '';
    btn.style.background = userProfile.avatarColor;
    btn.style.color = '';
  }
}

// ════════════════════════════════════════════════════════
//  TAB NAVIGATION
// ════════════════════════════════════════════════════════
function switchTab(name) {
  document.querySelectorAll('.tab-pane').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b=>b.classList.remove('active'));
  document.getElementById('pane-'+name).classList.add('active');
  document.querySelectorAll(`.nav-btn[data-tab="${name}"]`).forEach(b=>b.classList.add('active'));
  document.getElementById('fab').classList.toggle('hidden', name==='people' || name==='recap');
  updateNavIndicator();
  const inner = document.querySelector('.app-inner');
  if (inner) inner.scrollTop = 0;
  if (name === 'history') renderCalendar();
  if (name === 'recap') renderHistory();
}
document.querySelectorAll('.nav-btn').forEach(b=>b.addEventListener('click',()=>switchTab(b.dataset.tab)));
// ════════════════════════════════════════════════════════
//  CALENDAR HANDLERS
// ════════════════════════════════════════════════════════
let _calDayDate = null; // currently viewed date in cal-day panel
let _calAddType = 'attend'; // selected type in admin add form

function openCalDay(date) {
  _calDayDate = date;
  const entries = (data.entries || []).filter(e => e.date === date);
  const titleEl = document.getElementById('cal-day-title');
  const listEl  = document.getElementById('cal-day-list');
  if (titleEl) titleEl.textContent = fmtFull(date);
  if (listEl) {
    listEl.innerHTML = entries.map(e => {
      const isSkip = e.type === 'skip';
      const isAttendCal = e.type === 'attend';
      const badge = isSkip
        ? `<span class="skip-badge">&#x2298; ${esc(T.reasonLabel(e.reason)||T.skipped)}</span>`
        : isAttendCal
          ? `<span class="attend-badge">✓</span>`
          : `<span class="late-badge">${e.mins} ${T.minsShort}</span>`;
      const adminControls = adminMode ? `
        <button class="admin-del-entry-btn" data-id="${esc(e.id)}" style="background:none;border:none;color:var(--red,#ef4444);cursor:pointer;padding:4px 6px;font-size:15px;" title="${esc(T.admCalAddEntry)}">✕</button>` : '';
      return `<div class="entry" style="margin-bottom:8px">
        <div class="avatar">${esc(initials(e.person))}</div>
        <div class="entry-info"><div class="entry-name">${esc(e.person)}</div></div>
        ${badge}${adminControls}
      </div>`;
    }).join('') || (adminMode ? '' : `<div style="color:var(--text-2);text-align:center;padding:16px 0"></div>`);
  }

  // Admin add-entry form
  const addSection = document.getElementById('cal-day-admin-add');
  if (addSection) {
    addSection.style.display = adminMode ? '' : 'none';
    if (adminMode) {
      // Populate person select
      const sel = document.getElementById('cal-add-person');
      sel.innerHTML = (data.people || []).map(p => `<option value="${esc(p.name)}">${esc(p.name)}</option>`).join('');
      // Reset add type
      _calAddType = 'attend';
      document.getElementById('cal-add-mins-wrap').style.display = 'none';
      document.querySelectorAll('#cal-day-admin-add .mode-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.type === 'attend');
      });
      document.getElementById('cal-add-error').textContent = '';
    }
  }
  openPage('modal-cal-day');
}

document.getElementById('cal-grid').addEventListener('click', e => {
  const cell = e.target.closest('[data-date]');
  if (!cell || !data) return;
  const date = cell.dataset.date;
  const hasEntries = cell.classList.contains('cal-has-entries');
  // Allow tap if has entries OR admin mode (to add to any past day)
  if (!hasEntries && !adminMode) return;
  if (date >= todayStr() && !adminMode) return; // future days only editable in admin
  openCalDay(date);
});

// Admin delete entry from cal-day
document.getElementById('cal-day-list').addEventListener('click', async e => {
  const btn = e.target.closest('.admin-del-entry-btn');
  if (!btn || !adminMode || !data) return;
  const eid = btn.dataset.id;
  try {
    await api.delEntry(data.id, eid, adminPassword);
    await refresh();
    // Re-render the list if still open
    if (_calDayDate) openCalDay(_calDayDate);
    showToast(T.toastEntryDeleted);
  } catch { showToast(T.errServer); }
});

// Admin add-entry type toggle
document.querySelectorAll('#cal-day-admin-add .mode-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    _calAddType = btn.dataset.type;
    document.querySelectorAll('#cal-day-admin-add .mode-btn').forEach(b => b.classList.toggle('active', b === btn));
    document.getElementById('cal-add-mins-wrap').style.display = _calAddType === 'late' ? '' : 'none';
  });
});

// Admin add-entry submit
document.getElementById('cal-add-submit').addEventListener('click', async () => {
  if (!_calDayDate || !adminMode || !data) return;
  const person = document.getElementById('cal-add-person').value;
  const mins = _calAddType === 'late' ? parseInt(document.getElementById('cal-add-mins').value) || 10 : 0;
  const errEl = document.getElementById('cal-add-error');
  errEl.textContent = '';
  try {
    await api.addEntry(data.id, { person, date: _calDayDate, type: _calAddType, mins });
    await refresh();
    openCalDay(_calDayDate); // re-render list
    showToast(T.toastEntryAdded);
  } catch { errEl.textContent = T.errServer; }
});

document.getElementById('cal-day-close').addEventListener('click', () => closePage('modal-cal-day'));
document.getElementById('cal-prev').addEventListener('click', () => {
  calMonthIdx--; if (calMonthIdx < 0) { calMonthIdx = 11; calYear--; }
  renderCalendar();
});
document.getElementById('cal-next').addEventListener('click', () => {
  calMonthIdx++; if (calMonthIdx > 11) { calMonthIdx = 0; calYear++; }
  renderCalendar();
});
// Init nav indicator on load
requestAnimationFrame(() => { requestAnimationFrame(updateNavIndicator); });


