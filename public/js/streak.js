// ════════════════════════════════════════════════════════
//  STREAK HERO + STREAK ANIMATION
// ════════════════════════════════════════════════════════
function myStreakInfo() {
  const me = data?.people?.find(p => userProfile && p.id === userProfile.userId);
  if (!me) return null;
  const today = todayStr();
  const extendedToday = (data?.entries || []).some(e =>
    e.person === me.name && e.date === today &&
    (e.type === 'attend' || (e.type || 'late') === 'late'));
  return { streak: me.streak ?? 0, extendedToday };
}

function renderStreakHero() {
  const hero = document.getElementById('streak-hero');
  const info = myStreakInfo();
  if (!info) { hero.classList.add('hidden'); return; }
  hero.classList.remove('hidden');
  const wasLit = hero.classList.contains('lit');
  hero.classList.toggle('lit', info.extendedToday);
  if (info.extendedToday && !wasLit) {
    hero.classList.remove('just-extended');
    void hero.offsetHeight; // force reflow to restart animation
    hero.classList.add('just-extended');
  }
  document.getElementById('streak-hero-num').textContent = info.streak;
  document.getElementById('streak-hero-lbl').textContent = T.shDays(info.streak);
  document.getElementById('streak-hero-hint').textContent =
    info.extendedToday ? T.shHintDone : T.shHintOpen;
  renderCheckinTimeChip();
}

function renderCheckinTimeChip() {
  const hero = document.getElementById('checkin-time-hero');
  const hasTimeToday = !!data?.fixedCheckinEnabled && data?.checkinTimeDate === todayStr() && !!data?.checkinTime;
  hero.classList.toggle('hidden', !hasTimeToday);
  if (hasTimeToday) {
    document.getElementById('checkin-time-chip-lbl').textContent = T.checkinTimeChipLbl;
    document.getElementById('checkin-time-chip-val').textContent = data.checkinTime;
    document.getElementById('checkin-time-hint').textContent = T.checkinTimeChangeBtn;
    document.getElementById('checkin-time-save-btn').textContent = T.dhSetTimeBtn;
  }
}

function openCheckinTimeEditor() {
  document.getElementById('checkin-time-view').classList.add('hidden');
  document.getElementById('checkin-time-hint').classList.add('hidden');
  document.getElementById('checkin-time-editor').classList.remove('hidden');
  document.getElementById('checkin-time-edit-input').value = data?.checkinTime || '18:00';
}

function closeCheckinTimeEditor() {
  document.getElementById('checkin-time-view').classList.remove('hidden');
  document.getElementById('checkin-time-hint').classList.remove('hidden');
  document.getElementById('checkin-time-editor').classList.add('hidden');
}

document.getElementById('checkin-time-hint').addEventListener('click', e => {
  e.stopPropagation();
  openCheckinTimeEditor();
});

document.getElementById('checkin-time-save-btn').addEventListener('click', async e => {
  e.stopPropagation();
  const val = document.getElementById('checkin-time-edit-input').value;
  if (!val) return;
  const btn = e.target;
  btn.disabled = true;
  try {
    await api.setCheckinTime(data.id, { date: todayStr(), time: val });
    await refresh();
    updateDailyHypeTimeUI();
    closeCheckinTimeEditor();
  } catch { showToast(T.errServer); }
  finally { btn.disabled = false; }
});

// Tap on the hero opens the check-in modal
document.getElementById('streak-hero').addEventListener('click', () => {
  document.getElementById('fab')?.click();
});

function showStreakAnim(newStreak) {
  const el = document.getElementById('streak-anim');
  const num = document.getElementById('sa-num');
  document.getElementById('sa-lbl').textContent = `${T.saLbl(newStreak)}`;
  document.getElementById('sa-close').textContent = T.saContinue;
  // Restart CSS animations by re-inserting the flame wrap
  el.querySelectorAll('.sa-flame-wrap, .sa-num, .sa-lbl, .sa-btn-wrap').forEach(n => {
    n.style.animation = 'none'; void n.offsetHeight; n.style.animation = '';
  });
  num.textContent = Math.max(0, newStreak - 1);
  el.classList.remove('hidden');
  // Count up to the new streak as the flame ignites
  setTimeout(() => wCount(num, newStreak), 750);
}

document.getElementById('sa-close').addEventListener('click', () => {
  document.getElementById('streak-anim').classList.add('hidden');
  if (window._saNext) { const fn = window._saNext; window._saNext = null; fn(); }
});

// ════════════════════════════════════════════════════════
//  FIXED CHECK-IN TIME WINDOW (Beta)
// ════════════════════════════════════════════════════════
// Returns null if the beta feature isn't active for today, else { isLate, minsOff }.
// On-time = within ±10 minutes of the group's fixed check-in time for today.
function computeCheckinLateness() {
  if (!data?.fixedCheckinEnabled) return null;
  const today = todayStr();
  if (data.checkinTimeDate !== today || !data.checkinTime) return null;
  const [h, m] = data.checkinTime.split(':').map(Number);
  const now = new Date();
  const targetMins = h * 60 + m;
  const nowMins = now.getHours() * 60 + now.getMinutes();
  const diff = nowMins - targetMins;
  return { isLate: Math.abs(diff) > 10, minsOff: Math.abs(diff) };
}

function showLateAnim(minsOff) {
  document.getElementById('la-sub').textContent = T.laSub(minsOff);
  document.getElementById('late-anim').classList.remove('hidden');
}

document.getElementById('la-close').addEventListener('click', () => {
  document.getElementById('late-anim').classList.add('hidden');
  if (window._laNext) { const fn = window._laNext; window._laNext = null; fn(); }
});

// Shared submit path for a self/today attendance check-in (geo-prompt buttons).
// Applies the fixed-checkin-time window (if active) and plays the late-checkin
// animation before continuing into the normal streak-anim/chest/toast flow.
async function submitSelfAttendEntry() {
  if (!userProfile || !group || !data) return;
  try {
    const lateness = computeCheckinLateness();
    const wasExtended = myStreakInfo()?.extendedToday;
    const res = await api.addEntry(data.id, lateness?.isLate
      ? { type: 'late', date: todayStr(), person: userProfile.name, mins: lateness.minsOff }
      : { type: 'attend', date: todayStr(), person: userProfile.name });
    await refresh();
    const info = myStreakInfo();
    const finish = () => {
      if (info && !wasExtended) {
        if (res.chest) window._saNext = () => showChest(res.chest);
        showStreakAnim(info.streak);
      } else {
        if (res.chest) showChest(res.chest);
        showToast(lateness ? (lateness.isLate ? T.toastLate : T.toastOnTime) : T.toastAttendSaved);
      }
    };
    if (lateness?.isLate) {
      window._laNext = finish;
      showLateAnim(lateness.minsOff);
    } else {
      finish();
    }
  } catch { showToast(T.errServer); }
}

