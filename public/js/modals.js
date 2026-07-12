// ════════════════════════════════════════════════════════
//  APPLY I18N
// ════════════════════════════════════════════════════════
function applyI18n() {
  const set = (id,v) => { const el=document.getElementById(id); if(el&&v) el.textContent=v; };
  set('ls-sub',T.lsTagline); set('ls-create-lbl',T.lsCreate); set('ls-join-lbl',T.lsJoin); set('ls-or',T.lsOr);
  set('ls-create-hint',T.lsCreateHint); set('ls-join-hint',T.lsJoinHint);
  set('ls-signin-btn',T.lsSigninBtn);
  set('ls-feat-streak',T.lsFeatStreak); set('ls-feat-checkin',T.lsFeatCheckin); set('ls-feat-group',T.lsFeatGroup);
  set('ls-admin-lbl',T.lsAdmin); set('ls-test-lbl',T.lsTestGroup); set('ls-admin-note',T.lsAdminNote);
  document.querySelectorAll('[data-tab="week"] .nav-lbl').forEach(el=>el.textContent=T.navWeek);
  document.querySelectorAll('[data-tab="history"] .nav-lbl').forEach(el=>el.textContent=T.navHistory);
  document.querySelectorAll('[data-tab="recap"] .nav-lbl').forEach(el=>el.textContent=T.navRecap);
  document.querySelectorAll('[data-tab="people"] .nav-lbl').forEach(el=>el.textContent=T.navPeople);
  set('lbl-week',T.lblWeek); set('lbl-history',T.lblHistory); set('lbl-people',T.lblPeople);
  set('s-count-lbl',T.sCountLbl); set('s-mins-lbl',T.sMinLbl);
  set('empty-week-txt',T.emptyWeek); set('empty-people-txt',T.emptyPeople); set('empty-people-sub',T.emptyPeopleSub);
  set('add-person-btn',T.addPerson); set('leave-btn',T.leaveGroup);
  set('mc-title',T.mcTitle); set('mc-lbl-name',T.mcLblName); set('mc-lbl-days',T.mcLblDays); set('mc-submit',T.mcSubmit);
  set('ms-title',T.msTitle); set('ms-sub',T.msSub); set('ms-copy',T.msCopy); set('ms-continue',T.msContinue);
  set('mj-title',T.mjTitle); set('mj-sub',T.mjSub); set('mj-lbl',T.mjLbl); set('mj-submit',T.mjSubmit);
  set('ml-title',T.mlTitle); set('ml-lbl-person',T.mlLblPerson); set('ml-lbl-date',T.mlLblDate); set('ml-lbl-mins',T.mlLblMins); set('ml-save',T.mlSave);
  set('ml-mode-attend',T.mlModeAttend); set('ml-mode-late',T.mlModeLate); set('ml-mode-skip',T.mlModeSkip);
  set('ml-lbl-attend-date',T.mlLblAttendDate);
  set('mset-title',T.msetTitle); set('mset-gymdays-lbl',T.msetGymDaysLbl); set('mset-avail-lbl',T.msetAvailLbl);
  set('mset-gym-save',T.msetGymSave); set('mset-avail-save',T.msetAvailSave);
  set('ml-lbl-skip-date',T.mlLblSkipDate); set('ml-lbl-reason',T.mlLblReason);
  set('ee-title',T.eeTitle); set('ee-mode-attend',T.mlModeAttend); set('ee-mode-late',T.mlModeLate); set('ee-mode-skip',T.mlModeSkip);
  set('ee-lbl-attend-date',T.mlLblAttendDate); set('ee-lbl-date',T.mlLblDate); set('ee-lbl-mins',T.mlLblMins);
  set('ee-lbl-skip-date',T.mlLblSkipDate); set('ee-lbl-reason',T.mlLblReason); set('ee-save',T.mlSave);
  set('ma-title',T.maTitle); set('ma-lbl',T.maLbl); set('ma-submit',T.maSubmit);
  set('adm-page-title',T.admTitle); set('adm-exit-btn',T.admExit);
  set('adm-section-data',T.admSectionData); set('adm-add-lbl',T.admAdd); set('adm-del-lbl',T.admDel);
  set('adm-section-ceremonies',T.admSectionCeremonies); set('adm-replay-lbl',T.admReplay);
  set('adm-force-hype-lbl',T.admForceHype); set('adm-force-geo-lbl',T.admForceGeo);
  set('adm-clear-flags-lbl',T.admClearFlags); set('adm-week-lbl',T.admWeekOn);
  set('adm-section-notif',T.admSectionNotif);
  set('adm-test-reminder-lbl',T.admTestReminder); set('adm-test-streak-lbl',T.admTestStreak);
  set('adm-test-activity-lbl',T.admTestActivity); set('adm-test-all-lbl',T.admTestAll);
  set('pill-hint', T.pillHint);
  // Groups section (People tab)
  set('lbl-groups',T.mgsTitle); set('pp-join-btn',T.mgsJoin); set('pp-create-btn',T.mgsCreate);
  // Overlays
  set('dh-title',T.dhTitle); set('dh-sub',T.dhSub); set('dh-close',T.dhClose);
  set('dh-time-picker-lbl',T.dhSetTimeLbl); set('dh-time-save',T.dhSetTimeBtn); set('dh-time-display-lbl',T.dhTimeSetLbl);
  set('gp-title',T.gpTitle); set('gp-sub',T.gpSub); set('gp-checkin',T.gpCheckin); set('gp-later',T.gpLater);
  set('gp-log-checkin',T.gpLogCheckinBtn); set('gp-later2',T.gpLater);
  set('la-title',T.laTitle); set('la-close',T.laClose);
  set('sa-close',T.saContinue);
  // Settings location
  set('mset-location-lbl',T.msetLocationLbl); set('mset-radius-lbl',T.msetRadiusLbl);
  set('mset-locate-btn',T.msetLocateBtn); set('mset-location-save',T.msetLocationSave);
  // Settings geo toggle
  set('mset-geo-lbl',T.msetGeoLbl); set('mset-geo-toggle-lbl',T.msetGeoToggleLbl);
  set('mset-geo-test',T.msetGeoTestBtn);
  // Settings fixed check-in time (beta)
  set('mset-fixedtime-lbl',T.msetFixedtimeLbl); set('mset-fixedtime-toggle-lbl',T.msetFixedtimeToggleLbl);
  // Settings loading animation
  set('mset-loading-lbl',T.msetLoadingLbl);
  set('mset-loadstyle-barbell',T.loadingBarbell); set('mset-loadstyle-flame',T.loadingFlame);
  set('mset-loadstyle-wordmark',T.loadingWordmark);
  // Settings notifications
  set('mset-notif-lbl',T.msetNotifLbl); set('mset-notif-reminders-lbl',T.msetNotifRemindersLbl);
  set('mset-reminder-time-lbl',T.msetReminderTimeLbl); set('mset-notif-streak-lbl',T.msetNotifStreakLbl);
  set('mset-notif-activity-lbl',T.msetNotifActivityLbl); set('mset-quiet-lbl',T.msetQuietLbl);
  set('mset-notif-members-lbl',T.msetNotifMembersLbl); set('mset-notif-save',T.msetNotifSave);
  // Profile view gym days
  set('pv-gym-days-lbl',T.pvGymDaysLbl);
  // Admin user edit
  set('au-days-lbl',T.auDaysLbl); set('au-stats-lbl',T.auStatsLbl);
  set('au-streak-lbl',T.auStreakLbl); set('au-freezes-lbl',T.auFreezesLbl);
  set('au-save',T.auSave); set('au-kick-btn',T.auKickBtn);
  // Profile setup
  set('psu-title',T.psuTitle); set('psu-name-lbl',T.psuNameLbl); set('psu-emoji-lbl',T.psuEmojiLbl); set('psu-color-lbl',T.psuColorLbl);
  set('psu-submit-new',T.psuCreate); set('psu-to-login',T.psuToLogin);
  set('psu-login-title',T.psuLoginTitle); set('psu-login-sub',T.psuLoginSub);
  set('psu-login-name-lbl',T.psuLoginNameLbl); set('psu-rc-lbl',T.psuRcLbl);
  set('psu-submit-login',T.psuLoginBtn); set('psu-to-new',T.psuToNew);
  // Recovery code
  set('rc-title',T.rcTitle); set('rc-sub',T.rcSub); set('rc-copy',T.rcCopy); set('rc-done',T.rcDone);
  // Account auth (email/password)
  set('aa-reg-title',T.aaRegTitle); set('aa-reg-email-lbl',T.aaEmailLbl); set('aa-reg-pw-lbl',T.aaPwLbl);
  set('aa-submit-register',T.aaRegBtn); set('aa-to-login',T.aaToLogin);
  set('aa-login-title',T.aaLoginTitle); set('aa-login-email-lbl',T.aaEmailLbl); set('aa-login-pw-lbl',T.aaPwLbl);
  set('aa-submit-login',T.aaLoginBtn); set('aa-to-register',T.aaToReg);
  set('aa-sso-or',T.lsOr);
  // Migrate popup
  set('mig-title',T.migTitle); set('mig-sub',T.migSub);
  set('mig-setpw-btn',T.migSetPw); set('mig-skip-btn',T.migSkip);
  set('mig-sso-or',T.lsOr);
  // Profile view
  set('notif-primer-title',T.notifPrimerTitle); set('notif-primer-body',T.notifPrimerBody);
  set('notif-primer-enable',T.notifPrimerEnable); set('notif-primer-later',T.notifPrimerLater);
  set('pv-settings-btn',T.pvSettingsBtn);
  set('pv-rc-lbl',T.pvRcLbl); set('pv-edit-btn',T.pvEditBtn); set('pv-kick-btn',T.pvKickBtn);
  set('pv-stat-count-lbl',T.pvStatCount); set('pv-stat-mins-lbl',T.pvStatMins);
  set('pv-creator-badge',T.pvCreatorBadge);
  // Edit profile
  set('ep-title',T.epTitle); set('ep-name-lbl',T.epNameLbl); set('ep-emoji-lbl',T.epEmojiLbl); set('ep-color-lbl',T.epColorLbl);
  set('ep-submit',T.epSave);
  set('psu-upload-btn', T.uploadPhoto); set('ep-upload-btn', T.uploadPhoto);
  // Recap replay button
  set('recap-replay-btn', T.recapReplayBtn);
  // Admin calendar add form
  set('cal-add-person-lbl', T.mlLblPerson); set('cal-add-type-lbl', T.mlTitle||T.eeTitle);
  set('cal-add-mins-lbl', T.mlLblMins); set('cal-add-submit', T.admCalAddEntry);
  // Invite
  set('invite-hint-txt',T.inviteHint); set('invite-btn',T.inviteBtn);
}

// Recap replay button — plays Wrapped (force mode, any week)
document.getElementById('recap-replay-btn').addEventListener('click', () => showWrapped(true));

// ════════════════════════════════════════════════════════
//  DAY PICKER HELPER
// ════════════════════════════════════════════════════════
function buildDayPicker(containerId, initialMask, disabledMask) {
  const el = document.getElementById(containerId);
  el.innerHTML = T.dayNames.map((name, i) => {
    const isActive = initialMask ? initialMask[i] === '1' : true;
    const isDisabled = disabledMask ? disabledMask[i] !== '1' : false;
    return `<button type="button" class="day-btn${isActive ? ' active' : ''}" data-idx="${i}"${isDisabled ? ' disabled style="opacity:.3"' : ''}>${esc(name)}</button>`;
  }).join('');
  el.querySelectorAll('.day-btn:not([disabled])').forEach(btn => {
    btn.addEventListener('click', () => btn.classList.toggle('active'));
  });
}

function getDayMask(containerId) {
  const el = document.getElementById(containerId);
  return Array.from(el.querySelectorAll('.day-btn')).map(b => b.classList.contains('active') ? '1' : '0').join('');
}

// ════════════════════════════════════════════════════════
//  MODAL: CREATE GROUP
// ════════════════════════════════════════════════════════
document.getElementById('btn-show-create').addEventListener('click', () => {
  document.getElementById('mc-name').value=''; document.getElementById('mc-error').textContent='';
  buildDayPicker('mc-day-picker', '1111100'); // Mon-Fri default
  openPage('modal-create'); setTimeout(()=>document.getElementById('mc-name').focus(),350);
});
document.getElementById('mc-cancel').addEventListener('click', ()=>closePage('modal-create'));
document.getElementById('mc-submit').addEventListener('click', async () => {
  const name = document.getElementById('mc-name').value.trim();
  const gymDays = getDayMask('mc-day-picker');
  if (!name) { document.getElementById('mc-error').textContent=T.errGroupName; return; }
  if (!gymDays.includes('1')) { document.getElementById('mc-error').textContent='Bitte mindestens einen Tag wählen.'; return; }
  document.getElementById('mc-submit').disabled=true;
  try {
    const g = await api.createGroup(name, gymDays);
    closePage('modal-create');
    document.getElementById('ms-code-boxes').innerHTML = g.code.split('').map(c=>`<div class="code-char">${esc(c)}</div>`).join('');
    document.getElementById('ms-copy').onclick    = ()=>copyToClipboard(g.code);
    document.getElementById('ms-continue').onclick = ()=>{ closeOv('modal-success'); pendingGroup=g; openProfileSetup(); };
    openOv('modal-success');
  } catch { document.getElementById('mc-error').textContent=T.errServer; }
  finally  { document.getElementById('mc-submit').disabled=false; }
});
document.getElementById('mc-name').addEventListener('keydown',e=>{if(e.key==='Enter')document.getElementById('mc-submit').click();});

document.getElementById('btn-admin-login').addEventListener('click', openAdminLogin);

document.getElementById('btn-create-test-group').addEventListener('click', async () => {
  if (!adminMode || !adminPassword) { openAdminLogin(); return; }
  const btn = document.getElementById('btn-create-test-group');
  btn.disabled = true;
  showLoading(true);
  try {
    const demo = await api.createTestGroup(adminPassword);
    saveUser(demo.group.id, demo.user);
    testEntryIds = demo.entryIds || [];
    pendingGroup = demo.group;
    await enterGroup(demo.group);
    activateAdmin({ silent: true });
    showToast(T.toastTestGroup);
    switchTab('history');
  } catch {
    adminMode = false;
    adminPassword = '';
    renderLandingAdminTools();
    showToast(T.errServer);
  } finally {
    showLoading(false);
    btn.disabled = false;
  }
});

// ════════════════════════════════════════════════════════
//  MODAL: JOIN GROUP
// ════════════════════════════════════════════════════════
document.getElementById('btn-show-join').addEventListener('click',()=>{
  document.getElementById('mj-code').value=''; document.getElementById('mj-error').textContent='';
  openPage('modal-join'); setTimeout(()=>document.getElementById('mj-code').focus(),350);
});
document.getElementById('mj-cancel').addEventListener('click',()=>closePage('modal-join'));
document.getElementById('mj-code').addEventListener('input',e=>{ e.target.value=e.target.value.toUpperCase().replace(/[^A-Z0-9]/g,''); });
document.getElementById('mj-submit').addEventListener('click', async ()=>{
  const code=document.getElementById('mj-code').value.trim().toUpperCase();
  if(code.length<6){document.getElementById('mj-error').textContent=T.errShort;return;}
  document.getElementById('mj-submit').disabled=true;
  try { const g=await api.joinGroup(code); closePage('modal-join'); pendingGroup=g; openProfileSetup(); }
  catch(e){ document.getElementById('mj-error').textContent=e.status===404?T.errNotFound:T.errServer; }
  finally { document.getElementById('mj-submit').disabled=false; }
});
document.getElementById('mj-code').addEventListener('keydown',e=>{if(e.key==='Enter')document.getElementById('mj-submit').click();});

// ════════════════════════════════════════════════════════
//  MODAL: LOG LATE
// ════════════════════════════════════════════════════════
document.getElementById('ml-mode-attend').addEventListener('click', () => setMlMode('attend'));
document.getElementById('ml-mode-late').addEventListener('click', () => setMlMode('late'));
document.getElementById('ml-mode-skip').addEventListener('click', () => setMlMode('skip'));

document.getElementById('fab').addEventListener('click', () => {
  if (!data?.people?.length) { showToast(T.noPeople); return; }
  const sel = document.getElementById('ml-person');
  sel.innerHTML = data.people.map(p => `<option value="${esc(p.name)}">${esc(p.name)}</option>`).join('');
  document.getElementById('ml-attend-date').value = todayStr();
  document.getElementById('ml-date').value         = todayStr();
  document.getElementById('ml-skip-date').value    = todayStr();
  document.getElementById('ml-mins').value         = '10';
  document.getElementById('ml-error').textContent  = '';
  mlSelReason = null;
  // Build reason chips fresh each open
  const chips = document.getElementById('ml-reason-chips');
  chips.innerHTML = SKIP_REASONS.map(r =>
    `<button class="reason-chip" data-reason="${r}">${esc(T.reasons[r])}</button>`
  ).join('');
  chips.querySelectorAll('.reason-chip').forEach(c => {
    c.addEventListener('click', () => {
      const already = c.classList.contains('sel');
      chips.querySelectorAll('.reason-chip').forEach(x => x.classList.remove('sel'));
      if (!already) { c.classList.add('sel'); mlSelReason = c.dataset.reason; }
      else mlSelReason = null;
    });
  });
  setMlMode('attend');
  openPage('modal-late');
});
document.getElementById('ml-cancel').addEventListener('click', () => closePage('modal-late'));
document.getElementById('ml-save').addEventListener('click', async () => {
  const person   = document.getElementById('ml-person').value;
  const errEl    = document.getElementById('ml-error');
  errEl.textContent = '';
  document.getElementById('ml-save').disabled = true;
  try {
    if (mlMode === 'attend') {
      const date = document.getElementById('ml-attend-date').value;
      if (!person || !date) { errEl.textContent = '⚠'; return; }
      const isSelfToday = person === userProfile?.name && date === todayStr();
      const lateness = isSelfToday ? computeCheckinLateness() : null;
      const wasExtended = myStreakInfo()?.extendedToday;
      const res = await api.addEntry(data.id, lateness?.isLate
        ? { person, date, type: 'late', mins: lateness.minsOff }
        : { person, date, type: 'attend' });
      closePage('modal-late');
      await refresh();
      const info = myStreakInfo();
      const finish = () => {
        if (info && isSelfToday && !wasExtended) {
          if (res.chest) window._saNext = () => showChest(res.chest);
          showStreakAnim(info.streak);
        } else {
          showToast(lateness ? (lateness.isLate ? T.toastLate : T.toastOnTime) : T.toastAttendSaved);
          if (res.chest) showChest(res.chest);
        }
      };
      if (lateness?.isLate) {
        window._laNext = finish;
        showLateAnim(lateness.minsOff);
      } else {
        finish();
      }
    } else if (mlMode === 'late') {
      const date = document.getElementById('ml-date').value;
      const mins = parseInt(document.getElementById('ml-mins').value);
      if (!person || !date || isNaN(mins) || mins < 1) { errEl.textContent = '⚠'; return; }
      const wasExtended = myStreakInfo()?.extendedToday;
      await api.addEntry(data.id, { person, date, mins, type: 'late' });
      closePage('modal-late');
      await refresh();
      const info = myStreakInfo();
      if (info && person === userProfile?.name && date === todayStr() && !wasExtended) {
        showStreakAnim(info.streak);
      } else {
        showToast(T.toastSaved);
      }
    } else {
      const date = document.getElementById('ml-skip-date').value;
      if (!person || !date) { errEl.textContent = '⚠'; return; }
      await api.addEntry(data.id, { person, date, type: 'skip', reason: mlSelReason });
      closePage('modal-late');
      await refresh();
      showToast(T.toastSkipSaved);
    }
  } catch { errEl.textContent = T.errServer; }
  finally  { document.getElementById('ml-save').disabled = false; }
});

// ════════════════════════════════════════════════════════
//  MODAL: EDIT ENTRY (admin only)
// ════════════════════════════════════════════════════════
let eeMode = 'attend', eeSelReason = null, eeEditingId = null;

function setEeMode(mode) {
  eeMode = mode;
  document.getElementById('ee-attend-fields').style.display = mode === 'attend' ? '' : 'none';
  document.getElementById('ee-late-fields').style.display   = mode === 'late'   ? '' : 'none';
  document.getElementById('ee-skip-fields').style.display   = mode === 'skip'   ? '' : 'none';
  document.getElementById('ee-mode-attend').classList.toggle('active', mode === 'attend');
  document.getElementById('ee-mode-late').classList.toggle('active',   mode === 'late');
  document.getElementById('ee-mode-skip').classList.toggle('active',   mode === 'skip');
}
document.getElementById('ee-mode-attend').addEventListener('click', () => setEeMode('attend'));
document.getElementById('ee-mode-late').addEventListener('click',   () => setEeMode('late'));
document.getElementById('ee-mode-skip').addEventListener('click',   () => setEeMode('skip'));

function openEditEntry(entryId) {
  if (!adminMode || !adminPassword || !data) return;
  const e = data.entries.find(x => x.id === entryId);
  if (!e) return;
  eeEditingId = entryId;
  document.getElementById('ee-title').textContent = `${T.eeTitle} — ${e.person}`;
  document.getElementById('ee-error').textContent = '';
  document.getElementById('ee-attend-date').value = e.date;
  document.getElementById('ee-date').value        = e.date;
  document.getElementById('ee-skip-date').value    = e.date;
  document.getElementById('ee-mins').value         = e.type === 'late' ? e.mins : 10;
  eeSelReason = e.type === 'skip' ? (e.reason || null) : null;
  const chips = document.getElementById('ee-reason-chips');
  chips.innerHTML = SKIP_REASONS.map(r =>
    `<button class="reason-chip${r === eeSelReason ? ' sel' : ''}" data-reason="${r}">${esc(T.reasons[r])}</button>`
  ).join('');
  chips.querySelectorAll('.reason-chip').forEach(c => {
    c.addEventListener('click', () => {
      const already = c.classList.contains('sel');
      chips.querySelectorAll('.reason-chip').forEach(x => x.classList.remove('sel'));
      if (!already) { c.classList.add('sel'); eeSelReason = c.dataset.reason; }
      else eeSelReason = null;
    });
  });
  setEeMode(e.type === 'attend' ? 'attend' : e.type === 'skip' ? 'skip' : 'late');
  openPage('modal-edit-entry');
}

document.getElementById('ee-cancel').addEventListener('click', () => closePage('modal-edit-entry'));
document.getElementById('ee-save').addEventListener('click', async () => {
  const errEl = document.getElementById('ee-error');
  errEl.textContent = '';
  if (!eeEditingId) return;
  document.getElementById('ee-save').disabled = true;
  try {
    let body;
    if (eeMode === 'attend') {
      const date = document.getElementById('ee-attend-date').value;
      if (!date) { errEl.textContent = '⚠'; return; }
      body = { date, type: 'attend' };
    } else if (eeMode === 'late') {
      const date = document.getElementById('ee-date').value;
      const mins = parseInt(document.getElementById('ee-mins').value);
      if (!date || isNaN(mins) || mins < 1) { errEl.textContent = '⚠'; return; }
      body = { date, mins, type: 'late' };
    } else {
      const date = document.getElementById('ee-skip-date').value;
      if (!date) { errEl.textContent = '⚠'; return; }
      body = { date, type: 'skip', reason: eeSelReason };
    }
    await api.patchEntry(data.id, eeEditingId, body, adminPassword);
    closePage('modal-edit-entry');
    await refresh();
    showToast(T.toastSaved);
  } catch { errEl.textContent = T.errServer; }
  finally  { document.getElementById('ee-save').disabled = false; }
});

// ════════════════════════════════════════════════════════
//  PILL, LEAVE, ADD PERSON, DELETE
// ════════════════════════════════════════════════════════
// pill removed — code copy moved to People tab invite card

