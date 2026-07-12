// ════════════════════════════════════════════════════════
//  ACCOUNT AUTH MODAL (email + password register / login)
// ════════════════════════════════════════════════════════
// `aaPurpose` tracks WHY the modal was opened, so the same register/login
// form can serve three callers:
//   'signup'  — brand-new profile creation (no recovery code path anymore)
//   'migrate' — an existing recovery-code user upgrading to an account
//   'signin'  — a returning account user signing in on this device
let aaPurpose = 'signup';

function openAccountAuth(mode, purpose) {
  aaPurpose = purpose || 'signup';
  document.getElementById('aa-reg-email').value = '';
  document.getElementById('aa-reg-pw').value = '';
  document.getElementById('aa-reg-error').textContent = '';
  document.getElementById('aa-login-email').value = '';
  document.getElementById('aa-login-pw').value = '';
  document.getElementById('aa-login-error').textContent = '';
  showAccountMode(mode || 'register');
  openPage('modal-account-auth');
}

function showAccountMode(mode) {
  document.getElementById('aa-register-mode').style.display = mode === 'register' ? '' : 'none';
  document.getElementById('aa-login-mode').style.display    = mode === 'login'    ? '' : 'none';
  const titleKey = mode === 'register' ? T.aaRegTitle : T.aaLoginTitle;
  document.getElementById('aa-bar-title').textContent = titleKey;
  if (mode === 'login') setTimeout(() => document.getElementById('aa-login-email').focus(), 100);
  else setTimeout(() => document.getElementById('aa-reg-email').focus(), 100);
}

document.getElementById('aa-to-login').addEventListener('click',    () => showAccountMode('login'));
document.getElementById('aa-to-register').addEventListener('click', () => showAccountMode('register'));
document.getElementById('aa-cancel').addEventListener('click',      () => closePage('modal-account-auth'));

// Landing-screen entry point: a returning account user on a fresh device
// (no local groups at all) signs in and gets every linked group at once.
document.getElementById('ls-signin-btn').addEventListener('click', () => openAccountAuth('login', 'signin'));

function isValidEmail(e) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e); }

async function afterAccountAuth(resp) {
  saveAccount(resp);
  if (aaPurpose === 'migrate') {
    const links = collectRecoveryLinks();
    try {
      await api.linkRecovery(resp.accountToken, links);
      // Refresh every locally-linked profile so recoveryCode is cleared and
      // future protected calls switch to the accountToken path.
      applyAccountGroups(await api.accountGroups(resp.accountToken));
    } catch { /* linking is best-effort; account itself is already saved */ }
    closePage('modal-account-auth');
    closeOv('modal-migrate');
    hideMigrateBanner();
    showToast(T.migSuccess);
    if (group) { userProfile = loadUser(group.id); renderAll(); }
  } else if (aaPurpose === 'signin') {
    applyAccountGroups(await api.accountGroups(resp.accountToken));
    closePage('modal-account-auth');
    const all = loadAllGroups();
    if (all.length) { loadUser(all[0].id); await enterGroup(all[0]); }
    else showScreen('landing');
  } else {
    // 'signup' — brand-new profile creation. Account now exists locally;
    // hand off to the normal name/avatar step (openProfileSetup will see
    // loadAccount() is populated and skip straight past the recovery-code
    // screen once that step also succeeds).
    closePage('modal-account-auth');
    openProfileSetup();
  }
}

document.getElementById('aa-submit-register').addEventListener('click', async () => {
  const email = document.getElementById('aa-reg-email').value.trim();
  const pw = document.getElementById('aa-reg-pw').value;
  const errEl = document.getElementById('aa-reg-error');
  if (!isValidEmail(email)) { errEl.textContent = T.aaErrEmail; return; }
  if (pw.length < 8) { errEl.textContent = T.aaErrPw; return; }
  errEl.textContent = '';
  document.getElementById('aa-submit-register').disabled = true;
  try {
    const r = await api.accountRegister(email, pw);
    await afterAccountAuth(r);
  } catch (e) {
    errEl.textContent = e.status === 409 ? T.aaErrTaken : T.errServer;
  } finally { document.getElementById('aa-submit-register').disabled = false; }
});

document.getElementById('aa-submit-login').addEventListener('click', async () => {
  const email = document.getElementById('aa-login-email').value.trim();
  const pw = document.getElementById('aa-login-pw').value;
  const errEl = document.getElementById('aa-login-error');
  if (!isValidEmail(email) || !pw) { errEl.textContent = T.aaErrWrong; return; }
  errEl.textContent = '';
  document.getElementById('aa-submit-login').disabled = true;
  try {
    const r = await api.accountLogin(email, pw);
    await afterAccountAuth(r);
  } catch (e) {
    errEl.textContent = e.status === 401 ? T.aaErrWrong : T.errServer;
  } finally { document.getElementById('aa-submit-login').disabled = false; }
});

// ════════════════════════════════════════════════════════
//  MIGRATION (existing recovery-code user → account)
// ════════════════════════════════════════════════════════
function openMigratePopup() {
  // Covers the inline Google button rendered directly in this popup (sso.js)
  // — clicking "Set email & password" also re-asserts this via openAccountAuth.
  aaPurpose = 'migrate';
  openOv('modal-migrate');
}
document.getElementById('mig-setpw-btn').addEventListener('click', () => {
  closeOv('modal-migrate');
  openAccountAuth('register', 'migrate');
});
document.getElementById('mig-skip-btn').addEventListener('click', () => {
  closeOv('modal-migrate');
});

// Deliberately intrusive: shown every time the app is opened (not a
// one-time nag) for as long as this device holds a legacy recovery-code
// profile with no linked account — dismissing it only hides it for the
// current view, it comes back next launch until the user actually migrates.
function shouldShowMigrateBanner() {
  if (loadAccount()) return false;
  return collectRecoveryLinks().length > 0;
}

function maybeShowMigrateBanner() {
  const el = document.getElementById('migrate-bubble');
  if (!shouldShowMigrateBanner()) { el.classList.remove('show'); return; }
  // Shares screen position with the opening-sequence bubble (#notif-bubble,
  // wrapped/hype/geo) — wait for that ceremony chain to finish emptying its
  // queue before showing this one, so they never visually stack.
  const trySow = () => {
    if (_bubbleQueue.length || document.getElementById('notif-bubble').classList.contains('show')) {
      setTimeout(trySow, 800);
      return;
    }
    document.getElementById('migrate-bubble-t1').textContent = T.migBannerTitle;
    document.getElementById('migrate-bubble-t2').textContent = T.migBannerSub;
    el.classList.add('show');
  };
  setTimeout(trySow, 600);
}

function hideMigrateBanner() {
  document.getElementById('migrate-bubble').classList.remove('show');
}

document.getElementById('migrate-bubble').addEventListener('click', e => {
  if (e.target.id === 'migrate-bubble-x' || e.target.closest('#migrate-bubble-x')) {
    hideMigrateBanner();
  } else {
    hideMigrateBanner();
    openMigratePopup();
  }
});
