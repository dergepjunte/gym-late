// ════════════════════════════════════════════════════════
//  DATE HELPERS
// ════════════════════════════════════════════════════════
const pad = n => String(n).padStart(2,'0');
function todayStr() { const d=new Date(); return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`; }
function fmtShort(s){ return new Date(s+'T12:00').toLocaleDateString(navigator.language,{day:'numeric',month:'short'}); }
function fmtFull(s) { return new Date(s+'T12:00').toLocaleDateString(navigator.language,{weekday:'short',day:'numeric',month:'short'}); }
function addDays(dateStr, n) {
  const d = new Date(dateStr+'T12:00'); d.setDate(d.getDate()+n);
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
}
function mondayOf(s) {
  const d=new Date(s+'T12:00'), day=d.getDay()||7; d.setDate(d.getDate()-day+1);
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
}
function sundayOf(m) {
  const d=new Date(m+'T12:00'); d.setDate(d.getDate()+6);
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
}

// ════════════════════════════════════════════════════════
//  API
// ════════════════════════════════════════════════════════
const api = {
  async req(method, path, body) {
    const opts = { method, headers:{'Content-Type':'application/json'} };
    if (body !== undefined) opts.body = JSON.stringify(body);
    const res = await fetch('/api'+path, opts);
    const d   = await res.json();
    if (!res.ok) { const e=new Error(d.error||'error'); e.status=res.status; throw e; }
    return d;
  },
  verifyAdmin:   (pw)      => api.req('POST', '/admin/verify', {password:pw}),
  createGroup:   (n,gd)   => api.req('POST', '/groups', {name:n, gym_days:gd}),
  patchGroup:    (id,d)   => api.req('PATCH', `/groups/${id}`, d),
  createTestGroup:p       => api.req('POST', '/test-group', {password:p}),
  joinGroup:      c       => api.req('POST', '/groups/join', {code:c}),
  getGroup:       id      => api.req('GET',  `/groups/${id}`),
  addMember:     (g,n)    => api.req('POST',   `/groups/${g}/members`, {name:n}),
  delMember:     (g,n)    => api.req('DELETE', `/groups/${g}/members/${encodeURIComponent(n)}`),
  addEntry:      (g,d)    => api.req('POST',   `/groups/${g}/entries`, d),
  delEntry:      (g,e,pw) => api.req('DELETE', `/groups/${g}/entries/${e}`, pw ? {adminPassword:pw} : undefined),
  patchEntry:    (g,e,d,pw) => api.req('PATCH',  `/groups/${g}/entries/${e}`, {...d, adminPassword:pw}),
  registerUser:  (g,d)    => api.req('POST',   `/groups/${g}/users`, d),
  loginUser:     (g,d)    => api.req('POST',   `/groups/${g}/users/login`, d),
  updateUser:    (g,u,d)  => api.req('PATCH',  `/groups/${g}/users/${u}`, d),
  kickUser:      (g,u,d)  => api.req('DELETE', `/groups/${g}/users/${u}`, d),
  testPush:      (type)   => api.req('POST', '/admin/test-push', { userId: userProfile?.userId, groupId: group?.id, adminPassword, type }),
  setCheckinTime:(g,d)    => api.req('POST',   `/groups/${g}/checkin-time`, d),
  // Global accounts (email/password + Apple/Google SSO)
  authConfig:      ()          => api.req('GET',  '/auth/config'),
  accountRegister: (email,pw)  => api.req('POST', '/account/register', {email, password:pw}),
  accountLogin:    (email,pw)  => api.req('POST', '/account/login', {email, password:pw}),
  accountApple:    (idToken,em)=> api.req('POST', '/account/apple', {identityToken:idToken, email:em}),
  accountGoogle:   (idToken)   => api.req('POST', '/account/google', {identityToken:idToken}),
  accountGroups:   (token)     => api.req('POST', '/account/groups', {accountToken:token}),
  linkRecovery:    (token,links)=> api.req('POST', '/account/link-recovery', {accountToken:token, links}),
};

// ════════════════════════════════════════════════════════
//  STATE
// ════════════════════════════════════════════════════════
let group = null, data = null, pollTimer = null;
let adminMode         = false;
let adminShowCurWeek  = false;
let adminPassword     = '';
let testEntryIds      = [];
let userProfile       = null;   // { userId, name, avatarEmoji, avatarColor, recoveryCode, isCreator }
let pendingGroup      = null;   // group waiting for profile setup

function loadAllGroups() { try { return JSON.parse(localStorage.getItem('gymGroups') || '[]'); } catch { return []; } }
function saveAllGroups(arr) { localStorage.setItem('gymGroups', JSON.stringify(arr)); }

function saveGroup(g) {
  group = {id:g.id, code:g.code, name:g.name};
  localStorage.setItem('gymGroup', JSON.stringify(group));
  // Keep a registry of all joined groups
  const all = loadAllGroups();
  const idx = all.findIndex(x => x.id === g.id);
  if (idx >= 0) all[idx] = {...all[idx], name: g.name, code: g.code};
  else all.push(group);
  saveAllGroups(all);
}
function loadGroup()  { try { group=JSON.parse(localStorage.getItem('gymGroup')||'null'); } catch { group=null; } }
function clearGroup() {
  // Remove from the all-groups list and clear active
  if (group) {
    const all = loadAllGroups().filter(x => x.id !== group.id);
    saveAllGroups(all);
  }
  group=null; data=null; localStorage.removeItem('gymGroup');
}

function saveUser(gid, u) { userProfile=u; localStorage.setItem('gymUser_'+gid, JSON.stringify(u)); }
function loadUser(gid)    { try { userProfile=JSON.parse(localStorage.getItem('gymUser_'+gid)||'null'); } catch { userProfile=null; } }
function clearUser(gid)   { userProfile=null; localStorage.removeItem('gymUser_'+gid); }

// ════════════════════════════════════════════════════════
//  ACCOUNT (global email/password + Apple/Google identity)
// ════════════════════════════════════════════════════════
let account = null; // { accountId, email, accountToken, hasPassword, providers }

function saveAccount(a) { account=a; localStorage.setItem('gymAccount', JSON.stringify(a)); }
function loadAccount()  { try { account=JSON.parse(localStorage.getItem('gymAccount')||'null'); } catch { account=null; } return account; }
function clearAccount() { account=null; localStorage.removeItem('gymAccount'); }

// Rebuild the full local multi-group state from one `/api/account/groups`
// response — this is what lets a single sign-in (new device, or right after
// migrating) restore every group without any per-group recovery code.
function applyAccountGroups(resp) {
  for (const g of (resp?.groups || [])) {
    saveGroup({ id: g.id, code: g.code, name: g.name });
    saveUser(g.id, { ...g.profile, recoveryCode: null });
  }
}

// Build the {groupId,userId,recoveryCode} list for every locally-known
// group that still has a plaintext recovery code — used to link everything
// in one migration-popup visit.
function collectRecoveryLinks() {
  return loadAllGroups()
    .map(g => { try { return { g, u: JSON.parse(localStorage.getItem('gymUser_'+g.id)||'null') }; } catch { return { g, u:null }; } })
    .filter(({u}) => u && u.recoveryCode)
    .map(({g,u}) => ({ groupId: g.id, userId: u.userId, recoveryCode: u.recoveryCode }));
}

// Avatar constants
const AVATAR_EMOJIS = ['🏋️'];
const AVATAR_COLORS = ['#7c3aed','#db2777','#dc2626','#ea580c','#ca8a04','#16a34a','#0891b2','#2563eb','#7e22ce','#475569'];
let selEmoji = '🏋️', selColor = '#7c3aed', selImg = null;
let epSelEmoji = '🏋️', epSelColor = '#7c3aed', epSelImg = null;
let _nsfwModel = null, _nsfwLoading = null;

// ════════════════════════════════════════════════════════
//  UTILS
// ════════════════════════════════════════════════════════
function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function initials(n){ return n.trim().split(/\s+/).map(w=>w[0]||'').join('').toUpperCase().slice(0,2)||'?'; }

function avatarHtml(p, cls) {
  const hasImg = p.avatarImg && p.avatarImg.startsWith('data:image/');
  const bg = hasImg ? 'transparent' : esc(p.avatarColor || '#7c3aed');
  const inner = hasImg
    ? `<img src="${p.avatarImg}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`
    : esc(p.avatarEmoji || '🏋️');
  return `<div class="avatar-circle${cls ? ' '+cls : ''}" style="background:${bg}">${inner}</div>`;
}

function setAvatarEl(el, p) {
  const hasImg = p && p.avatarImg && p.avatarImg.startsWith('data:image/');
  if (hasImg) {
    el.innerHTML = `<img src="${p.avatarImg}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`;
    el.style.background = 'transparent';
  } else {
    el.textContent = p ? (p.avatarEmoji || '🏋️') : '🏋️';
    el.style.background = p ? (p.avatarColor || '#7c3aed') : '#7c3aed';
  }
}

function resizeImageToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      const c = document.createElement('canvas');
      c.width = 200; c.height = 200;
      const s = Math.min(img.width, img.height);
      c.getContext('2d').drawImage(img, (img.width-s)/2, (img.height-s)/2, s, s, 0, 0, 200, 200);
      resolve(c.toDataURL('image/jpeg', 0.82));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('load_failed')); };
    img.src = url;
  });
}

async function isImageSafe(dataUrl) {
  if (!_nsfwLoading) {
    _nsfwLoading = (async () => {
      const load = src => new Promise((res, rej) => {
        const s = document.createElement('script'); s.src = src;
        s.onload = res; s.onerror = rej; document.head.appendChild(s);
      });
      await load('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/dist/tf.min.js');
      _nsfwModel = await tf.loadGraphModel('/nsfw-model/model.json');
    })();
  }
  try {
    await _nsfwLoading;
  } catch {
    _nsfwLoading = null;
    throw new Error('nsfw_unavailable');
  }
  const img = new Image();
  await new Promise((resolve, reject) => {
    img.onload = resolve;
    img.onerror = reject;
    img.src = dataUrl;
    if (img.complete) resolve();
  });
  const tensor = tf.tidy(() =>
    tf.browser.fromPixels(img).resizeBilinear([224, 224]).expandDims(0).div(255.0)
  );
  let result = await _nsfwModel.executeAsync(tensor);
  tensor.dispose();
  if (Array.isArray(result)) result = result[0];
  const values = await result.data();
  result.dispose();
  // class order: Drawing(0), Hentai(1), Neutral(2), Porn(3), Sexy(4)
  const porn = values[3], hentai = values[1], sexy = values[4];
  return porn < 0.15 && hentai < 0.15 && sexy < 0.5;
}

function handleAvatarUpload(inputId, previewId, uploadBtnId, msgId, onImg) {
  const input   = document.getElementById(inputId);
  const preview = document.getElementById(previewId);
  const btn     = document.getElementById(uploadBtnId);
  const msg     = document.getElementById(msgId);

  btn.addEventListener('click', () => {
    if (btn.dataset.hasImg === '1') {
      onImg(null);
      btn.dataset.hasImg = '0';
      btn.textContent = T.uploadPhoto;
      preview.textContent = preview.dataset.emoji || '🏋️';
      preview.style.background = preview.dataset.color || '#7c3aed';
      msg.style.display = 'none';
    } else {
      input.click();
    }
  });

  input.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    msg.style.display = '';
    msg.style.color = 'var(--text-3)';
    msg.textContent = T.nsfwChecking;
    btn.disabled = true;
    try {
      const dataUrl = await resizeImageToDataUrl(file);
      const safe = await isImageSafe(dataUrl);
      if (!safe) {
        msg.style.color = '#ef4444';
        msg.textContent = T.nsfwError;
        onImg(null);
        btn.dataset.hasImg = '0';
        btn.textContent = T.uploadPhoto;
        preview.textContent = preview.dataset.emoji || '🏋️';
        preview.style.background = preview.dataset.color || '#7c3aed';
      } else {
        msg.style.display = 'none';
        onImg(dataUrl);
        btn.dataset.hasImg = '1';
        btn.textContent = T.removePhoto;
        preview.innerHTML = `<img src="${dataUrl}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`;
        preview.style.background = 'transparent';
      }
    } catch {
      msg.style.color = '#ef4444';
      msg.textContent = T.errServer;
    } finally {
      btn.disabled = false;
      e.target.value = '';
    }
  });
}

let toastTimer;
function showToast(msg) {
  const el = document.getElementById('toast');
  el.textContent = msg; el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), 2300);
}

function copyToClipboard(txt) {
  navigator.clipboard?.writeText(txt).then(()=>showToast(T.toastCopied)).catch(()=>{
    const ta=document.createElement('textarea'); ta.value=txt;
    ta.style.cssText='position:fixed;opacity:0'; document.body.appendChild(ta);
    ta.select(); try{document.execCommand('copy');showToast(T.toastCopied);}catch{}
    document.body.removeChild(ta);
  });
}

// ════════════════════════════════════════════════════════
//  SCREENS & OVERLAYS
// ════════════════════════════════════════════════════════
function showLoading(y){
  const el = document.getElementById('loading');
  if (y) el.dataset.style = localStorage.getItem('gymLoadingStyle') || 'barbell';
  el.classList.toggle('hidden',!y);
}
function showScreen(id){
  document.querySelectorAll('.screen').forEach(s=>s.classList.add('hidden'));
  document.getElementById('screen-'+id).classList.remove('hidden');
  if (id === 'landing') renderLandingAdminTools();
}
function openOv(id){ document.getElementById(id).classList.add('open'); }
function closeOv(id){ document.getElementById(id).classList.remove('open'); }
function openPage(id){ document.getElementById(id).classList.add('open'); }
function closePage(id){ document.getElementById(id).classList.remove('open'); }
function showFsOverlay(id){ document.getElementById(id)?.classList.remove('hidden'); }
function hideFsOverlay(id){ document.getElementById(id)?.classList.add('hidden'); }

function renderLandingAdminTools() {
  const show = adminMode && !group;
  document.getElementById('btn-create-test-group').classList.toggle('hidden', !show);
  document.getElementById('ls-admin-note').classList.toggle('hidden', !show);
}

// ════════════════════════════════════════════════════════
//  CONFETTI
// ════════════════════════════════════════════════════════
function spawnConfetti(host) {
  const colors = ['#facc15','#fbbf24','#f472b6','#34d399','#60a5fa','#fb923c','#fff176','#f59e0b'];
  for (let i = 0; i < 48; i++) {
    const el   = document.createElement('div');
    el.className = 'cbit';
    const size   = 5 + Math.random() * 7;
    const isCirc = Math.random() > .55;
    const isRect = !isCirc && Math.random() > .4;
    el.style.cssText = `
      left:${4+Math.random()*92}%;
      width:${isRect?size*2.2:size}px; height:${size}px;
      background:${colors[i%colors.length]};
      border-radius:${isCirc?'50%':'3px'};
      --cr:${Math.random()*360-180}deg;
      --cr2:${Math.random()>0.5?360:-360}deg;
      --cd:${0.65+Math.random()*0.9}s;
      --cdelay:${Math.random()*0.45}s;
    `;
    host.appendChild(el);
    setTimeout(() => el.remove(), 1800);
  }
}

// ════════════════════════════════════════════════════════
//  SKIP MODE STATE
// ════════════════════════════════════════════════════════
let mlMode = 'attend'; // 'attend' | 'late' | 'skip'
let mlSelReason = null;
const SKIP_REASONS = ['rest', 'sick', 'injured', 'no_time', 'deload'];

function setMlMode(mode) {
  mlMode = mode;
  document.getElementById('ml-attend-fields').style.display = mode === 'attend' ? '' : 'none';
  document.getElementById('ml-late-fields').style.display   = mode === 'late'   ? '' : 'none';
  document.getElementById('ml-skip-fields').style.display   = mode === 'skip'   ? '' : 'none';
  document.getElementById('ml-mode-attend').classList.toggle('active', mode === 'attend');
  document.getElementById('ml-mode-late').classList.toggle('active',   mode === 'late');
  document.getElementById('ml-mode-skip').classList.toggle('active',   mode === 'skip');
  document.getElementById('ml-save').textContent =
    mode === 'attend' ? T.mlLogAttend : mode === 'late' ? T.mlSave : T.mlLogSkip;
}


