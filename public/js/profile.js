// ════════════════════════════════════════════════════════
//  PROFILE SETUP MODAL
// ════════════════════════════════════════════════════════
handleAvatarUpload('psu-img-input', 'psu-preview', 'psu-upload-btn', 'psu-upload-msg', img => { selImg = img; });
handleAvatarUpload('ep-img-input',  'ep-preview',  'ep-upload-btn',  'ep-upload-msg',  img => { epSelImg = img; });

function openProfileSetup() {
  // Recovery codes are retired for brand-new profiles: anyone without an
  // account yet is routed through email/password signup first. Once
  // afterAccountAuth('signup') completes it calls openProfileSetup() again,
  // this time with loadAccount() populated, and we fall through below.
  // Existing recovery-code users are unaffected — "Already registered? Log
  // in →" (below) still works with no account at all.
  if (!loadAccount()) {
    openAccountAuth('register', 'signup');
    return;
  }
  selEmoji = '🏋️'; selColor = '#7c3aed'; selImg = null;
  const prev = document.getElementById('psu-preview');
  prev.textContent = selEmoji;
  prev.style.background = selColor;
  prev.dataset.emoji = selEmoji;
  prev.dataset.color = selColor;
  const uploadBtn = document.getElementById('psu-upload-btn');
  uploadBtn.textContent = T.uploadPhoto;
  uploadBtn.dataset.hasImg = '0';
  document.getElementById('psu-upload-msg').style.display = 'none';
  document.getElementById('psu-name').value = '';
  document.getElementById('psu-error').textContent = '';
  document.getElementById('psu-login-name').value = '';
  document.getElementById('psu-rc-input').value = '';
  document.getElementById('psu-login-error').textContent = '';

  // Build emoji grid
  const eg = document.getElementById('psu-emoji-grid');
  eg.innerHTML = AVATAR_EMOJIS.map(em =>
    `<div class="emoji-cell${em===selEmoji?' sel':''}" data-emoji="${em}">${em}</div>`
  ).join('');
  eg.querySelectorAll('.emoji-cell').forEach(c => {
    c.addEventListener('click', () => {
      eg.querySelectorAll('.emoji-cell').forEach(x=>x.classList.remove('sel'));
      c.classList.add('sel');
      selEmoji = c.dataset.emoji;
      prev.dataset.emoji = selEmoji;
      if (!selImg) prev.textContent = selEmoji;
    });
  });

  // Build color grid
  const cg = document.getElementById('psu-color-grid');
  cg.innerHTML = AVATAR_COLORS.map(col =>
    `<div class="color-dot${col===selColor?' sel':''}" data-color="${col}" style="background:${col}"></div>`
  ).join('');
  cg.querySelectorAll('.color-dot').forEach(c => {
    c.addEventListener('click', () => {
      cg.querySelectorAll('.color-dot').forEach(x=>x.classList.remove('sel'));
      c.classList.add('sel');
      selColor = c.dataset.color;
      prev.dataset.color = selColor;
      if (!selImg) prev.style.background = selColor;
    });
  });

  showMode('new');
  openPage('modal-profile-setup');
  setTimeout(() => document.getElementById('psu-name').focus(), 350);
}

function showMode(mode) {
  document.getElementById('psu-new-mode').style.display   = mode==='new'   ? '' : 'none';
  document.getElementById('psu-login-mode').style.display = mode==='login' ? '' : 'none';
  document.getElementById('psu-preview').style.display = mode==='new' ? 'inline-flex' : 'none';
  if (mode==='login') setTimeout(() => document.getElementById('psu-login-name').focus(), 100);
}

document.getElementById('psu-to-login').addEventListener('click',   () => showMode('login'));
document.getElementById('psu-to-new').addEventListener('click',     () => showMode('new'));
document.getElementById('psu-cancel').addEventListener('click',     () => closePage('modal-profile-setup'));

// Format recovery code input as XXXX-XXXX-XXXX
document.getElementById('psu-rc-input').addEventListener('input', e => {
  let v = e.target.value.toUpperCase().replace(/[^A-Z2-9]/g,'');
  if (v.length > 4)  v = v.slice(0,4) + '-' + v.slice(4);
  if (v.length > 9)  v = v.slice(0,9) + '-' + v.slice(9);
  e.target.value = v.slice(0,14);
});

document.getElementById('psu-submit-new').addEventListener('click', async () => {
  const name = document.getElementById('psu-name').value.trim();
  const errEl = document.getElementById('psu-error');
  if (!name) { errEl.textContent = T.psuErrName; return; }
  errEl.textContent = '';
  document.getElementById('psu-submit-new').disabled = true;
  try {
    const acc = loadAccount();
    const r = await api.registerUser(pendingGroup.id, {
      name, avatarEmoji: selEmoji, avatarColor: selColor, avatarImg: selImg,
      accountToken: acc?.accountToken,
    });
    saveUser(pendingGroup.id, { userId:r.userId, name:r.name, avatarEmoji:r.avatarEmoji, avatarColor:r.avatarColor, avatarImg:r.avatarImg||null, recoveryCode:r.recoveryCode||null, isCreator:r.isCreator });
    closePage('modal-profile-setup');
    if (r.recoveryCode) showRecoveryCode(r.recoveryCode);
    else enterGroup(pendingGroup);
  } catch(e) {
    errEl.textContent = e.status===409 ? T.psuErrTaken : T.errServer;
  } finally { document.getElementById('psu-submit-new').disabled = false; }
});
document.getElementById('psu-name').addEventListener('keydown', e => { if(e.key==='Enter') document.getElementById('psu-submit-new').click(); });

document.getElementById('psu-submit-login').addEventListener('click', async () => {
  const name = document.getElementById('psu-login-name').value.trim();
  const code = document.getElementById('psu-rc-input').value.trim();
  const errEl = document.getElementById('psu-login-error');
  if (!name || !code) { errEl.textContent = T.psuErrName; return; }
  errEl.textContent = '';
  document.getElementById('psu-submit-login').disabled = true;
  try {
    const r = await api.loginUser(pendingGroup.id, { name, recoveryCode: code });
    saveUser(pendingGroup.id, { userId:r.userId, name:r.name, avatarEmoji:r.avatarEmoji, avatarColor:r.avatarColor, avatarImg:r.avatarImg||null, recoveryCode: code.replace(/-/g,'').toUpperCase(), isCreator:r.isCreator });
    closePage('modal-profile-setup');
    enterGroup(pendingGroup);
  } catch(e) {
    errEl.textContent = e.status===401 ? T.psuErrWrongCode : (e.status===404 ? T.psuErrNotFound : T.errServer);
  } finally { document.getElementById('psu-submit-login').disabled = false; }
});

// ════════════════════════════════════════════════════════
//  RECOVERY CODE MODAL
// ════════════════════════════════════════════════════════
function showRecoveryCode(code) {
  const parts = code.split('-');
  document.getElementById('rc-boxes').innerHTML = parts.map(p =>
    `<div class="rc-box">${esc(p)}</div>`
  ).join('');
  document.getElementById('rc-copy').onclick = () => copyToClipboard(code);
  document.getElementById('rc-done').onclick = () => { closeOv('modal-recovery-code'); enterGroup(pendingGroup); };
  openOv('modal-recovery-code');
}

// ════════════════════════════════════════════════════════
//  PROFILE VIEW MODAL
// ════════════════════════════════════════════════════════
let viewingUserId = null;

function openProfileView(userId) {
  viewingUserId = userId;
  const user = data?.people?.find(p => p.id === userId);
  if (!user) return;

  const isOwnProfile   = userProfile && userProfile.userId === userId;
  const isCreatorView  = userProfile?.isCreator && !isOwnProfile;
  const isAdminView    = adminMode && !isOwnProfile;

  setAvatarEl(document.getElementById('pv-avatar'), user);
  document.getElementById('pv-name').textContent = user.name;

  const badge = document.getElementById('pv-creator-badge');
  badge.style.display = user.isCreator ? '' : 'none';

  const userLate = (data?.entries||[]).filter(e => e.person === user.name && (e.type||'late') === 'late');
  document.getElementById('pv-stat-count').textContent = userLate.length;
  document.getElementById('pv-stat-mins').textContent  = userLate.reduce((s,e)=>s+e.mins,0);

  // Gym days chips
  const gymDaysMask = user.availDays || data?.gymDays || '1111100';
  const chipsEl = document.getElementById('pv-day-chips');
  chipsEl.innerHTML = T.dayNames.map((name, i) =>
    gymDaysMask[i] === '1' ? `<span class="pv-day-chip">${name}</span>` : ''
  ).join('');

  const ownSection  = document.getElementById('pv-own-section');
  const kickSection = document.getElementById('pv-kick-section');
  ownSection.style.display  = isOwnProfile  ? '' : 'none';
  kickSection.style.display = (isCreatorView || isAdminView) ? '' : 'none';

  if (isOwnProfile && userProfile.recoveryCode) {
    const rc = userProfile.recoveryCode;
    const rcEl = document.getElementById('pv-rc-value');
    rcEl.textContent = rc;
    rcEl.classList.remove('revealed');
    document.getElementById('pv-rc-reveal').textContent = T.pvReveal;
    document.getElementById('pv-rc-reveal').onclick = () => {
      const revealed = rcEl.classList.toggle('revealed');
      document.getElementById('pv-rc-reveal').textContent = revealed ? T.pvHide : T.pvReveal;
    };
    rcEl.onclick = () => {
      if (rcEl.classList.contains('revealed')) {
        copyToClipboard(rc);
        showToast(T.pvRcCopied);
      } else {
        rcEl.classList.add('revealed');
        document.getElementById('pv-rc-reveal').textContent = T.pvHide;
      }
    };
  }

  openPage('modal-profile-view');
}

document.getElementById('pv-close').addEventListener('click', () => closePage('modal-profile-view'));

document.getElementById('pv-edit-btn').addEventListener('click', () => {
  closePage('modal-profile-view');
  openEditProfile();
});

document.getElementById('pv-settings-btn').addEventListener('click', () => {
  closePage('modal-profile-view');
  openSettings();
});

document.getElementById('pv-kick-btn').addEventListener('click', async () => {
  const user = data?.people?.find(p => p.id === viewingUserId);
  if (!user) return;
  if (!confirm(T.pvKickConfirm(user.name))) return;
  try {
    const body = adminMode && adminPassword
      ? { adminPassword }
      : { actorUserId: userProfile.userId, actorRecoveryCode: userProfile.recoveryCode };
    await api.kickUser(group.id, viewingUserId, body);
    closePage('modal-profile-view');
    await refresh();
    showToast(T.toastKicked);
  } catch { showToast(T.errServer); }
});

document.getElementById('my-profile-btn').addEventListener('click', () => {
  if (userProfile) openProfileView(userProfile.userId);
});

