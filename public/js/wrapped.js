// ════════════════════════════════════════════════════════
//  WRAPPED ENGINE
// ════════════════════════════════════════════════════════
let wSlides = [], wIdx = 0, wTimer = null;

function shouldShowWrapped() {
  const mon = mondayOf(todayStr());
  if (localStorage.getItem('gymWrappedSeen') === mon) return false;
  return (data?.entries || []).some(e => mondayOf(e.date) === mon && ((e.type || 'late') === 'late' || e.type === 'skip'));
}

function showWrapped(force = false) {
  const slides = buildWrappedSlides(force);
  if (!slides?.length) { showToast(T.noMembersForTest); return; }
  wSlides = slides;
  wIdx = 0;

  // Build progress bar
  const prog = document.getElementById('w-prog');
  prog.innerHTML = slides.map((_,i) =>
    `<div class="w-seg"><div class="w-fill" id="wf${i}"></div></div>`
  ).join('');

  showFsOverlay('wrapped');
  wShowSlide(0);

  if (!force) localStorage.setItem('gymWrappedSeen', mondayOf(todayStr()));
}

function wShowSlide(idx) {
  clearTimeout(wTimer);
  wIdx = idx;
  const slide = wSlides[idx];

  // Fill past segments instantly
  wSlides.forEach((_, i) => {
    const f = document.getElementById(`wf${i}`);
    if (!f) return;
    f.style.transition = 'none';
    f.style.width = i < idx ? '100%' : '0%';
  });

  // Render
  const stage = document.getElementById('w-stage');
  stage.innerHTML = `<div class="w-slide w-in" style="background:${slide.bg}">${slide.html}</div>`;

  // Wire close button if present
  const cb = stage.querySelector('#w-close');
  if (cb) cb.addEventListener('click', wClose);

  // Count-up animation
  if (slide.countId && slide.countTarget != null) {
    setTimeout(() => {
      const el = document.getElementById(slide.countId);
      if (el) wCount(el, slide.countTarget);
    }, 280);
  }

  // Progress + auto-advance
  if (!slide.isLast) {
    setTimeout(() => {
      const f = document.getElementById(`wf${idx}`);
      if (f) { f.style.transition = `width ${slide.dur||4}s linear`; f.style.width = '100%'; }
      wTimer = setTimeout(() => wAdvance(1), (slide.dur||4) * 1000);
    }, 60);
  } else {
    const f = document.getElementById(`wf${idx}`);
    if (f) { f.style.transition = 'none'; f.style.width = '100%'; }
  }
}

function wAdvance(dir) {
  clearTimeout(wTimer);
  const next = wIdx + dir;
  if (next < 0) {
    // Shake on back-on-first
    const s = document.querySelector('.w-slide');
    if (s) { s.style.animation = 'w-shake .3s ease'; setTimeout(() => s.style.animation='', 350); }
    return;
  }
  if (next >= wSlides.length) { wClose(); return; }

  // Quick exit anim then enter next
  const cur = document.querySelector('.w-slide');
  if (cur) {
    cur.classList.remove('w-in');
    cur.classList.add('w-out');
    setTimeout(() => wShowSlide(next), 200);
  } else {
    wShowSlide(next);
  }
}

function wClose() {
  clearTimeout(wTimer);
  hideFsOverlay('wrapped');
  // Advance opening sequence if running
  if (window._seqWrappedNext) {
    const fn = window._seqWrappedNext;
    window._seqWrappedNext = null;
    fn();
  }
}

function wCount(el, target) {
  const dur = Math.min(1400, 500 + target * 25);
  const t0 = Date.now();
  const tick = () => {
    const p = Math.min((Date.now() - t0) / dur, 1);
    const e = 1 - Math.pow(1 - p, 3); // ease-out cubic
    el.textContent = Math.round(target * e);
    if (p < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

// Build slides — anyWeek=true uses the most recent week with data (for admin replay)
function buildWrappedSlides(anyWeek = false) {
  const allEntries = data?.entries || [];
  let mon, sun;

  if (anyWeek) {
    const mons = [...new Set(allEntries.map(e => mondayOf(e.date)))].sort().reverse();
    if (!mons.length) return null;
    mon = mons[0];
  } else {
    mon = mondayOf(todayStr());
  }
  sun = sundayOf(mon);

  const weekEntries = allEntries.filter(e => e.date >= mon && e.date <= sun);
  const lateEntries = weekEntries.filter(e => (e.type || 'late') === 'late');
  const skipEntries = weekEntries.filter(e => e.type === 'skip');
  if (!lateEntries.length && !skipEntries.length) return null;

  const totalLate = lateEntries.length;
  const totalMins = lateEntries.reduce((s,e) => s + e.mins, 0);
  const hours = Math.floor(totalMins / 60), remMins = totalMins % 60;

  const ps = {};
  lateEntries.forEach(e => { ps[e.person] = ps[e.person]||{count:0,mins:0}; ps[e.person].count++; ps[e.person].mins+=e.mins; });
  const ranking = Object.entries(ps).sort((a,b) => b[1].mins - a[1].mins);
  const medals = ['🥇','🥈','🥉'];

  const sps = {};
  skipEntries.forEach(e => { sps[e.person] = (sps[e.person]||0) + 1; });
  const skipRanking = Object.entries(sps).sort((a,b) => b[1] - a[1]);

  const slides = [];

  /* ── Slide 1: Intro ── */
  slides.push({ dur: 3, bg: 'linear-gradient(160deg,#f59e0b 0%,#ea580c 100%)', html: `
    <div class="w-group w-fade">${esc(data.name)}</div>
    <div class="w-gap-sm"></div>
    <div class="w-emoji w-pop">🏋️</div>
    <div class="w-gap-sm"></div>
    <div class="w-headline w-rise" style="animation-delay:.25s">${T.wS1a}</div>
    <div class="w-headline w-rise" style="animation-delay:.4s;color:rgba(255,255,255,.35)">${T.wS1b}</div>
    <div class="w-gap"></div>
    <div class="w-label w-fade" style="animation-delay:.65s">${T.weekRange(mon,sun)}</div>
  `});

  if (lateEntries.length) {
    const [topName, topSt] = ranking[0];

    /* ── Slide 2: Late count ── */
    slides.push({ dur: 4, countId:'wn-late', countTarget: totalLate,
      bg: 'linear-gradient(160deg,#db2777 0%,#ea580c 100%)', html: `
      <div class="w-label w-fade">${T.wS2label}</div>
      <div class="w-gap-xs"></div>
      <div class="w-number w-pop" id="wn-late" style="animation-delay:.1s">0</div>
      <div class="w-gap-xs"></div>
      <div class="w-sub w-rise" style="animation-delay:.3s">${T.wS2sub}</div>
      <div class="w-gap"></div>
      <div class="w-emoji w-pop" style="animation-delay:.5s;font-size:clamp(36px,12vw,58px)">🚨</div>
    `});

    /* ── Slide 3: Minutes ── */
    slides.push({ dur: 4, countId:'wn-mins', countTarget: totalMins,
      bg: 'linear-gradient(160deg,#059669 0%,#0891b2 100%)', html: `
      <div class="w-label w-fade">${T.wS3label}</div>
      <div class="w-gap-xs"></div>
      <div class="w-number w-pop" id="wn-mins" style="animation-delay:.1s">0</div>
      <div class="w-sub w-rise" style="animation-delay:.3s">${T.wS3sub}</div>
      ${hours > 0 ? `<div class="w-gap-sm"></div><div class="w-label w-fade" style="animation-delay:.55s">${T.wS3hours(hours,remMins)}</div>` : ''}
    `});

    /* ── Slide 4: Top latecomer ── */
    slides.push({ dur: 4.5, bg: 'linear-gradient(160deg,#ca8a04 0%,#dc2626 100%)', html: `
      <div class="w-emoji w-pop">👑</div>
      <div class="w-gap-sm"></div>
      <div class="w-label w-rise" style="animation-delay:.2s">${T.wS4label}</div>
      <div class="w-gap-sm"></div>
      <div class="w-name w-pop" style="animation-delay:.38s">${esc(topName)}</div>
      <div class="w-gap"></div>
      <div class="w-sub w-fade" style="animation-delay:.6s">${topSt.count}× · ${topSt.mins} ${T.minsShort}</div>
    `});
  }

  /* ── Slide: Skips ── */
  if (skipEntries.length) {
    const [topSkipName, topSkipCount] = skipRanking[0];
    slides.push({ dur: 4, countId:'wn-skip', countTarget: skipEntries.length,
      bg: 'linear-gradient(160deg,#6366f1 0%,#4338ca 100%)', html: `
      <div class="w-label w-fade">${T.wSkipLabel}</div>
      <div class="w-gap-xs"></div>
      <div class="w-number w-pop" id="wn-skip" style="animation-delay:.1s">0</div>
      <div class="w-gap-xs"></div>
      <div class="w-sub w-rise" style="animation-delay:.3s">${T.wSkipSub}</div>
      <div class="w-gap"></div>
      <div class="w-emoji w-pop" style="animation-delay:.5s;font-size:clamp(36px,12vw,58px)">⊘</div>
      <div class="w-gap-sm"></div>
      <div class="w-sub w-fade" style="animation-delay:.65s">${esc(T.wSkipTop(topSkipName, topSkipCount))}</div>
    `});
  }

  /* ── Slide 5: Ranking (only if >1 person) ── */
  if (ranking.length > 1) {
    slides.push({ dur: 5, bg: 'linear-gradient(160deg,#b45309 0%,#78350f 100%)', html: `
      <div class="w-headline-md w-rise">${T.wS5title}</div>
      <div class="w-divider"></div>
      <div class="w-ranks">
        ${ranking.slice(0,5).map(([name,st],i) => `
          <div class="w-rank-row w-rise" style="animation-delay:${.2+i*.13}s">
            <div class="w-medal">${medals[i]||(i+1)+'.'}</div>
            <div class="w-rank-name">${esc(name)}</div>
            <div class="w-rank-mins">${st.mins} ${T.minsShort}</div>
          </div>`).join('')}
      </div>
    `});
  }

  /* ── Slide 6: End card ── */
  slides.push({ isLast: true, bg: 'linear-gradient(160deg,#78350f 0%,#b45309 100%)', html: `
    <div class="w-emoji w-pop">💪</div>
    <div class="w-gap-sm"></div>
    <div class="w-headline w-rise" style="animation-delay:.2s;font-size:clamp(44px,14vw,78px)">${T.wS6a}</div>
    <div class="w-headline w-rise" style="animation-delay:.36s;font-size:clamp(44px,14vw,78px);color:rgba(255,255,255,.35)">${T.wS6b}</div>
    <div class="w-gap-lg"></div>
    <button class="w-btn-close w-pop" id="w-close" style="animation-delay:.6s">${T.wClose}</button>
  `});

  return slides;
}

// Tap zones
document.getElementById('w-tap-l').addEventListener('click', () => wAdvance(-1));
document.getElementById('w-tap-r').addEventListener('click', () => wAdvance(1));
document.getElementById('w-skip').addEventListener('click', wClose);

// Swipe support
let wTouchX = 0;
const wEl = document.getElementById('wrapped');
wEl.addEventListener('touchstart', e => { wTouchX = e.touches[0].clientX; }, { passive: true });
wEl.addEventListener('touchend', e => {
  const dx = e.changedTouches[0].clientX - wTouchX;
  if (Math.abs(dx) > 48) wAdvance(dx < 0 ? 1 : -1);
});

// Keyboard
document.addEventListener('keydown', e => {
  if (document.getElementById('wrapped').classList.contains('hidden')) return;
  if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); wAdvance(1); }
  if (e.key === 'ArrowLeft') { e.preventDefault(); wAdvance(-1); }
  if (e.key === 'Escape') wClose();
});

