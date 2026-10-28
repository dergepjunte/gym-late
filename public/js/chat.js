// ════════════════════════════════════════════════════════
//  GROUP CHAT  (text + gym-time proposals with majority vote)
// ════════════════════════════════════════════════════════
const CHAT_DE = {
  nav:'Chat', title:'Gruppen-Chat', empty:'Noch nichts hier', emptySub:'Schreib etwas oder schlag die Gym-Zeit für heute vor – sie gilt, sobald die Gruppe zustimmt.',
  placeholder:'Nachricht …', proposes:n=>`${n} schlägt vor`, today:'Heute', tomorrow:'Morgen', open:'Offen', accepted:'Angenommen', rejected:'Abgelehnt', superseded:'Überholt',
  inN:(y,m)=>`${y} von ${m} dabei`, imIn:'Ich bin dabei ✓', no:'Nein', youIn:'Du bist dabei ✓', youNo:'Du bist raus',
  timeSet:(d,t)=>`${d} · Gym-Zeit steht: ${t}`, proposeTitle:'Gym-Zeit vorschlagen', propose:'Vorschlagen', note:'Die Zeit gilt erst, wenn die Mehrheit der Gruppe zustimmt.',
  scopeToday:'Heute', scopeAll:'Alle', emptyToday:'Heute noch nichts los',
  proposed:'Vorschlag im Chat – wird fix, sobald die Gruppe zustimmt.', toChat:'Zum Chat', sendErr:'Senden fehlgeschlagen.', someone:'Jemand',
};
const CHAT_EN = {
  nav:'Chat', title:'Group chat', empty:'Nothing here yet', emptySub:"Say something or propose today's gym time – it counts once the group agrees.",
  placeholder:'Message …', proposes:n=>`${n} proposes`, today:'Today', tomorrow:'Tomorrow', open:'Open', accepted:'Accepted', rejected:'Rejected', superseded:'Superseded',
  inN:(y,m)=>`${y} of ${m} in`, imIn:"I'm in ✓", no:'No', youIn:"You're in ✓", youNo:"You're out",
  timeSet:(d,t)=>`${d} · gym time set: ${t}`, proposeTitle:'Propose gym time', propose:'Propose', note:'The time becomes fixed once most of the group agrees.',
  scopeToday:'Today', scopeAll:'All time', emptyToday:'Nothing yet today',
  proposed:'Proposed in chat – becomes fixed once the group agrees.', toChat:'Open chat', sendErr:'Could not send.', someone:'Someone',
};
const CT = (navigator.language||'').toLowerCase().startsWith('de') ? CHAT_DE : CHAT_EN;

const chat = { msgs:[], members:0, timer:null, lastKey:'', sheetDay:'today', todayOnly:true };
try { chat.todayOnly = localStorage.getItem('gymChatScope') !== 'all'; } catch {}

// Filter: only today's messages, or all of them.
function chatVisible() {
  if (!chat.todayOnly) return chat.msgs;
  const d = new Date(); d.setHours(0,0,0,0);
  return chat.msgs.filter(m => m.createdAt >= d.getTime());
}
function setChatScope(todayOnly) {
  chat.todayOnly = todayOnly;
  try { localStorage.setItem('gymChatScope', todayOnly ? 'today' : 'all'); } catch {}
  document.querySelectorAll('#chat-scope button').forEach(b => b.classList.toggle('sel', (b.dataset.scope === 'today') === todayOnly));
  renderChat();
  const l = document.getElementById('chat-list'); if (l) l.scrollTop = l.scrollHeight;
}

function chatAuth() {
  return { userId: userProfile?.userId, recoveryCode: userProfile?.recoveryCode, accountToken: account?.accountToken };
}
function chatReq(action, extra) {
  return api.req('POST', `/groups/${group.id}/chat/${action}`, { ...chatAuth(), ...(extra||{}) });
}
function chatDayWord(dateStr) {
  if (dateStr === todayStr()) return CT.today;
  if (dateStr === addDays(todayStr(), 1)) return CT.tomorrow;
  return fmtFull ? fmtFull(dateStr) : dateStr;
}
function chatPerson(id) { return (data?.people||[]).find(p => p.id === id); }
function chatAvatar(id) {
  const p = chatPerson(id);
  if (!p) return '<div class="avatar chat-av">?</div>';
  if (p.avatarImg) return `<img class="chat-av-img" src="${esc(p.avatarImg)}" alt="">`;
  return `<div class="avatar chat-av" style="background:${esc(p.avatarColor)}22">${esc(p.avatarEmoji)}</div>`;
}

function renderChat() {
  const list = document.getElementById('chat-list');
  if (!list) return;
  const me = userProfile?.userId;
  const stick = list.scrollHeight - list.scrollTop - list.clientHeight < 80;
  const msgs = chatVisible();
  if (!msgs.length) {
    const title = chat.todayOnly && chat.msgs.length ? CT.emptyToday : CT.empty;
    list.innerHTML = `<div class="empty"><div class="empty-ico">💬</div><div class="empty-txt">${esc(title)}</div><div class="empty-sub">${esc(CT.emptySub)}</div></div>`;
  } else {
    list.innerHTML = msgs.map(m => {
      const mine = m.userId === me;
      const name = chatPerson(m.userId)?.name || CT.someone;
      if (m.kind === 'system') {
        return `<div class="chat-sys">⏰ ${esc(CT.timeSet(chatDayWord(m.propDate), m.propTime))}</div>`;
      }
      if (m.kind === 'time_proposal') {
        const myVote = m.yes.includes(me) ? 'yes' : m.no.includes(me) ? 'no' : null;
        const pct = chat.members ? Math.min(100, Math.round(m.yes.length / chat.members * 100)) : 0;
        const st = m.status || 'open';
        const stLbl = CT[st] || st;
        const btns = st === 'open' ? `
          <div class="cp-btns">
            <button class="cp-yes${myVote==='yes'?' on':''}" data-vote="yes" data-id="${esc(m.id)}">${esc(myVote==='yes'?CT.youIn:CT.imIn)}</button>
            <button class="cp-no${myVote==='no'?' on':''}" data-vote="no" data-id="${esc(m.id)}">${esc(myVote==='no'?CT.youNo:CT.no)}</button>
          </div>` : '';
        return `<div class="chat-prop st-${esc(st)}">
          <div class="cp-head">${chatAvatar(m.userId)}<div class="cp-who">${esc(CT.proposes(name))}<br><span>${esc(chatDayWord(m.propDate))}</span></div><span class="cp-badge">${esc(stLbl)}</span></div>
          <div class="cp-time">${esc(m.propTime)}</div>
          <div class="cp-bar"><i style="width:${pct}%"></i></div>
          <div class="cp-count">${esc(CT.inN(m.yes.length, chat.members))}</div>${btns}</div>`;
      }
      return `<div class="chat-row${mine?' mine':''}">${mine?'':chatAvatar(m.userId)}<div class="chat-bubble">${mine?'':`<div class="cb-name">${esc(name)}</div>`}${esc(m.text||'')}</div></div>`;
    }).join('');
  }
  if (stick) list.scrollTop = list.scrollHeight;
}

function chatApply(snap) {
  chat.msgs = snap.messages || [];
  chat.members = snap.members || 0;
  const key = JSON.stringify(chat.msgs);
  const changed = key !== chat.lastKey;
  chat.lastKey = key;
  if (changed) {
    renderChat();
    const last = chat.msgs[chat.msgs.length-1];
    if (last && last.kind === 'system') refresh().catch(()=>{});
  }
}
async function chatLoad() {
  if (!group || !userProfile) return;
  try { chatApply(await chatReq('list')); } catch {}
}
function chatStart() { chatStop(); chatLoad(); chat.timer = setInterval(chatLoad, 4000); }
function chatStop()  { if (chat.timer) { clearInterval(chat.timer); chat.timer = null; } }

async function chatSend() {
  const inp = document.getElementById('chat-input');
  const text = inp.value.trim();
  if (!text) return;
  inp.value = '';
  try { chatApply(await chatReq('send', { text })); const l=document.getElementById('chat-list'); l.scrollTop=l.scrollHeight; }
  catch { showToast(CT.sendErr); inp.value = text; }
}

// Proposes a time; used by the chat sheet, the week hero and the daily hype.
async function proposeGymTime(date, time) {
  const snap = await chatReq('propose', { date, time });
  chatApply(snap);
  return snap;
}

function openProposeSheet() {
  const ov = document.getElementById('chat-prop-overlay');
  document.getElementById('chat-prop-time').value = data?.checkinTime || '18:00';
  setProposeDay('today');
  ov.classList.add('open');
}
function setProposeDay(d) {
  chat.sheetDay = d;
  document.querySelectorAll('#chat-prop-days button').forEach(b => b.classList.toggle('sel', b.dataset.day === d));
}

function initChatUI() {
  document.getElementById('chat-send').addEventListener('click', chatSend);
  document.getElementById('chat-input').addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); chatSend(); } });
  document.getElementById('chat-alarm').addEventListener('click', openProposeSheet);
  document.getElementById('chat-list').addEventListener('click', async e => {
    const b = e.target.closest('[data-vote]'); if (!b) return;
    try { chatApply(await chatReq('vote', { messageId: b.dataset.id, vote: b.dataset.vote })); }
    catch (err) { if (err.status === 409) chatLoad(); else showToast(T.errServer); }
  });
  document.querySelectorAll('#chat-prop-days button').forEach(b => b.addEventListener('click', () => setProposeDay(b.dataset.day)));
  const ov = document.getElementById('chat-prop-overlay');
  ov.addEventListener('click', e => { if (e.target === ov) ov.classList.remove('open'); });
  document.getElementById('chat-prop-go').addEventListener('click', async () => {
    const time = document.getElementById('chat-prop-time').value; if (!time) return;
    const date = chat.sheetDay === 'tomorrow' ? addDays(todayStr(), 1) : todayStr();
    const btn = document.getElementById('chat-prop-go'); btn.disabled = true;
    try { await proposeGymTime(date, time); ov.classList.remove('open'); }
    catch { showToast(T.errServer); }
    finally { btn.disabled = false; }
  });
  document.getElementById('chat-title').textContent = CT.title;
  document.querySelector('#chat-scope [data-scope="today"]').textContent = CT.scopeToday;
  document.querySelector('#chat-scope [data-scope="all"]').textContent = CT.scopeAll;
  document.querySelectorAll('#chat-scope button').forEach(b => b.addEventListener('click', () => setChatScope(b.dataset.scope === 'today')));
  setChatScope(chat.todayOnly);
  document.getElementById('chat-input').placeholder = CT.placeholder;
  document.getElementById('chat-prop-title').textContent = CT.proposeTitle;
  document.getElementById('chat-prop-note').textContent = CT.note;
  document.getElementById('chat-prop-go').textContent = CT.propose;
  document.querySelector('#chat-prop-days [data-day="today"]').textContent = CT.today;
  document.querySelector('#chat-prop-days [data-day="tomorrow"]').textContent = CT.tomorrow;
  document.querySelectorAll('[data-tab="chat"] .nav-lbl').forEach(el => el.textContent = CT.nav);
}
initChatUI();
