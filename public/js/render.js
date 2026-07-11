// ════════════════════════════════════════════════════════
//  RENDER: WEEK
// ════════════════════════════════════════════════════════

function getMyEffectiveMask() {
  const gymDays = data?.gymDays || '0000000';
  if (!userProfile || !data || gymDays.length !== 7) return gymDays;
  const me = data.people.find(p => p.id === userProfile.userId);
  const avail = me?.availDays;
  if (!avail || avail.length !== 7) return gymDays;
  let r = '';
  for (let i = 0; i < 7; i++) r += (gymDays[i] === '1' && avail[i] === '1') ? '1' : '0';
  return r;
}

function renderWeek() {
  if (!data) return;
  const mon = mondayOf(todayStr()), sun = sundayOf(mon);
  const allWeek   = data.entries.filter(e => e.date >= mon && e.date <= sun);
  const lateWeek  = allWeek.filter(e => (e.type || 'late') === 'late');
  const skipWeek  = allWeek.filter(e => e.type === 'skip');
  const totalMins = lateWeek.reduce((s, e) => s + e.mins, 0);

  const cEl = document.getElementById('s-count'), mEl = document.getElementById('s-mins');
  cEl.textContent = lateWeek.length; mEl.textContent = totalMins;
  cEl.classList.toggle('red', lateWeek.length > 0);

  const skipWrap = document.getElementById('skip-stat-wrap');
  skipWrap.classList.toggle('hidden', skipWeek.length === 0);
  if (skipWeek.length) document.getElementById('skip-stat-chip').textContent = `⊘ ${skipWeek.length} ${T.skipped}`;

  const emEl = document.getElementById('week-empty'), lEl = document.getElementById('week-list');
  const weekCard = document.getElementById('week-card');

  // Group entries by date
  const byDate = {};
  allWeek.forEach(e => { (byDate[e.date] = byDate[e.date] || []).push(e); });

  // All 7 week dates newest-first (Sun → Mon)
  const weekDates = [];
  for (let i = 6; i >= 0; i--) weekDates.push(addDays(mon, i));

  const mask = getMyEffectiveMask();
  // Visible: days with entries OR rest days (bit=0 in effective mask)
  const visibleDates = weekDates.filter(d => byDate[d] || !calDayScheduled(d, mask));

  if (!visibleDates.length) {
    emEl.style.display = '';
    lEl.innerHTML = '';
    weekCard.classList.add('card', 'glass');
    return;
  }
  emEl.style.display = 'none';
  weekCard.classList.remove('card', 'glass');

  let animIdx = 0;
  lEl.innerHTML = visibleDates.map(date => {
    const dayEntries = byDate[date];
    if (!dayEntries) {
      // Rest day — no entries for anyone on this day
      return `<div class="day-group glass day-rest"><div class="day-group-label">🌙 ${fmtFull(date)}</div><div class="rest-day-row">${T.restDay}</div></div>`;
    }
    const rows = dayEntries.map(e => {
      const isSkip   = e.type === 'skip';
      const isAttend = e.type === 'attend';
      const skipLabel = e.auto ? T.noShow : (T.reasonLabel(e.reason) || T.skipped);
      const badge  = isSkip
        ? `<div class="skip-badge">⊘ ${esc(skipLabel)}</div>`
        : isAttend
          ? `<div class="attend-badge">✓</div>`
          : `<div class="late-badge">${e.mins} ${T.minsShort}</div>`;
      const delay = animIdx++ * 45;
      return `
        <div class="entry animate" style="animation-delay:${delay}ms">
          ${personAvatar(e.person)}
          <div class="entry-info"><div class="entry-name">${esc(e.person)}</div></div>
          ${badge}
          ${adminMode ? `
          <button class="icon-btn edit-entry-btn" data-id="${esc(e.id)}" title="Edit">✎</button>
          <button class="icon-btn del-entry-btn" data-id="${esc(e.id)}">×</button>` : ''}
        </div>`;
    }).join('');
    return `<div class="day-group glass"><div class="day-group-label">${fmtFull(date)}</div>${rows}</div>`;
  }).join('');
}

// ════════════════════════════════════════════════════════
//  RENDER: HISTORY  (with full animation sequence)
// ════════════════════════════════════════════════════════
function personAvatar(name, size) {
  size = size || 38;
  var p = (data.people || []).find(function(p) { return p.name.toLowerCase() === name.toLowerCase(); });
  if (!p) return '<div class="avatar">' + esc(initials(name)) + '</div>';
  if (p.avatarImg) return '<img src="' + esc(p.avatarImg) + '" style="width:' + size + 'px;height:' + size + 'px;border-radius:50%;object-fit:cover;flex-shrink:0" alt="">';
  return '<div class="avatar" style="background:' + esc(p.avatarColor) + '22;font-size:' + Math.round(size * 0.54) + 'px;width:' + size + 'px;height:' + size + 'px">' + esc(p.avatarEmoji) + '</div>';
}

function renderHistory() {
  if (!data) return;
  const currentMon = mondayOf(todayStr());
  const weeks = {};
  data.entries.forEach(e => {
    const mon = mondayOf(e.date);
    if (mon === currentMon && !adminShowCurWeek) return;
    (weeks[mon] = weeks[mon] || []).push(e);
  });

  const root = document.getElementById('week-recap');
  const sorted = Object.keys(weeks).sort().reverse();

  if (!sorted.length) {
    root.innerHTML = `<div class="card glass"><div class="empty"><div class="empty-txt">${esc(T.emptyHistory)}</div></div></div>`;
    return;
  }

  const medals = ['1.','2.','3.'];

  // Pre-build per-week stats for comparison lookups
  const weekStats = sorted.map(mon => {
    const entries = weeks[mon];
    const late    = entries.filter(e => (e.type || 'late') === 'late');
    const skip    = entries.filter(e => e.type === 'skip');
    const attend  = entries.filter(e => e.type === 'attend');
    const ps = {};
    late.forEach(e => { ps[e.person] = ps[e.person] || {count:0,mins:0,skips:0,attends:0}; ps[e.person].count++; ps[e.person].mins += e.mins; });
    skip.forEach(e => { ps[e.person] = ps[e.person] || {count:0,mins:0,skips:0,attends:0}; ps[e.person].skips++; });
    attend.forEach(e => { ps[e.person] = ps[e.person] || {count:0,mins:0,skips:0,attends:0}; ps[e.person].attends++; });
    const byMins   = Object.entries(ps).filter(([,s]) => s.count > 0).sort((a,b) => b[1].mins-a[1].mins || b[1].count-a[1].count);
    const skipOnly = Object.entries(ps).filter(([,s]) => s.count === 0 && s.skips > 0);
    const totalLateMins = Object.values(ps).reduce((acc, s) => acc + s.mins, 0);
    const minsPerDay = [0,0,0,0,0,0,0];
    late.forEach(e => { const dow = new Date(e.date+'T12:00:00Z').getUTCDay(); minsPerDay[dow===0?6:dow-1] += e.mins; });
    const mostPunctual = Object.entries(ps).filter(([,s]) => s.attends > 0).sort((a,b) => b[1].attends-a[1].attends)[0] || null;
    return { mon, ps, byMins, skipOnly, totalLateMins, minsPerDay, mostPunctual };
  });

  const dayLabels = T.dayNames;

  root.innerHTML = weekStats.map(({ mon, ps, byMins, skipOnly, totalLateMins, minsPerDay, mostPunctual }, wi) => {
    const sun      = sundayOf(mon);
    const prevSt   = wi + 1 < weekStats.length ? weekStats[wi + 1] : null;
    const BASE     = wi * 60;

    // Hero
    const heroHtml = byMins.length ? `
      <div class="recap-hero confetti-host">
        <div class="recap-trophy-wrap"><span class="recap-trophy anim-trophy" style="animation-delay:${BASE+100}ms">★</span></div>
        <div class="recap-name anim-name" style="animation-delay:${BASE+270}ms">${esc(byMins[0][0])}</div>
        <div class="recap-role anim-fade-up" style="animation-delay:${BASE+400}ms">${esc(T.lateKing)}</div>
      </div>` : `
      <div class="recap-hero" style="padding:18px 18px 14px;text-align:center">
        <div style="font-size:36px;margin-bottom:6px">⊘</div>
        <div class="recap-name">${esc(T.allSkippedTitle)}</div>
      </div>`;

    // Ranked rows — use AvatarView equivalent
    const lateRows = byMins.map(([name, st], i) => {
      const skipTag = st.skips > 0 ? ` <span class="skip-badge" style="font-size:11px;padding:1px 7px">⊘${st.skips}</span>` : '';
      return `
        <div class="rank-row ${i===0?'rank-gold':''} anim-rank" style="animation-delay:${BASE+520+i*130}ms">
          <div class="rank-no">${medals[i] || (i+1)+'.'}</div>
          ${personAvatar(name)}
          <div class="entry-info">
            <div class="entry-name">${esc(name)}${skipTag}</div>
            <div class="entry-meta">${T.timesLate(st.count)}</div>
          </div>
          <div class="late-badge">${st.mins} ${T.minsShort}</div>
        </div>`;
    }).join('');

    const skipRows = skipOnly.map(([name, st], i) => `
      <div class="rank-row anim-rank" style="animation-delay:${BASE+520+(byMins.length+i)*130}ms">
        <div class="rank-no" style="color:var(--gold)">⊘</div>
        ${personAvatar(name)}
        <div class="entry-info">
          <div class="entry-name">${esc(name)}</div>
          <div class="entry-meta">${st.skips}× ${T.skipped}</div>
        </div>
        <div class="skip-badge">⊘ ${st.skips}</div>
      </div>`).join('');

    // Card A: trend chart (pure CSS bars, no external lib)
    const maxMins = Math.max(1, ...minsPerDay);
    const trendBars = minsPerDay.map((mins, i) => {
      const h = mins === 0 ? 2 : Math.max(4, Math.round(mins / maxMins * 72));
      return `<div class="trend-col">
        <div class="trend-bar ${mins===0?'trend-ghost':'trend-real'}" style="height:${h}px"></div>
        <div class="trend-day-lbl">${esc(dayLabels[i].charAt(0))}</div>
      </div>`;
    }).join('');
    const trendHtml = `<hr class="recap-divider">
      <div class="recap-trend">
        <div class="recap-trend-lbl">${esc(T.recapTrendTitle)}</div>
        <div class="trend-bars">${trendBars}</div>
      </div>`;

    // Card B: week comparison
    let compareHtml;
    if (prevSt) {
      const delta = totalLateMins - prevSt.totalLateMins;
      const arrow  = delta < 0 ? '↓' : delta === 0 ? '→' : '↑';
      const color  = delta < 0 ? 'var(--green)' : delta === 0 ? 'var(--gold)' : '#ef4444';
      const verdict = delta < 0 ? T.recapBetterWeek : delta === 0 ? T.recapSameWeek : T.recapWorseWeek;
      const deltaStr = delta < 0 ? `−${Math.abs(delta)} ${T.minsShort}` : delta === 0 ? `±0 ${T.minsShort}` : `+${delta} ${T.minsShort}`;
      compareHtml = `<hr class="recap-divider">
        <div class="recap-compare">
          <span class="recap-compare-arrow" style="color:${color}">${arrow}</span>
          <div>
            <div class="recap-compare-delta" style="color:${color}">${esc(deltaStr)}</div>
            <div class="recap-compare-verdict">${esc(verdict)}</div>
          </div>
        </div>`;
    } else {
      compareHtml = `<hr class="recap-divider">
        <div class="recap-compare">
          <span class="recap-compare-arrow" style="color:var(--text-3)">—</span>
          <div class="recap-compare-verdict">${esc(T.recapFirstWeek)}</div>
        </div>`;
    }

    // Card C: positive cards
    const improved = prevSt ? Object.entries(ps)
      .filter(([,s]) => s.count > 0)
      .map(([name, s]) => ({ name, delta: ((prevSt.ps[name]||{}).mins||0) - s.mins }))
      .filter(x => x.delta > 0)
      .sort((a,b) => b.delta - a.delta)[0] || null : null;

    let positiveHtml = '';
    if (mostPunctual || improved) {
      const rows = [];
      if (mostPunctual) {
        rows.push(`<div class="recap-pos-row">
          <span class="recap-pos-icon">🏅</span>
          ${personAvatar(mostPunctual[0], 32)}
          <div class="recap-pos-info">
            <div class="recap-pos-label">${esc(T.recapMostPunctual)}</div>
            <div class="recap-pos-name">${esc(mostPunctual[0])}</div>
          </div>
          <div class="recap-pos-meta">${esc(T.recapOnTime(mostPunctual[1].attends))}</div>
        </div>`);
      }
      if (improved) {
        rows.push(`<div class="recap-pos-row">
          <span class="recap-pos-icon">📈</span>
          ${personAvatar(improved.name, 32)}
          <div class="recap-pos-info">
            <div class="recap-pos-label">${esc(T.recapMostImproved)}</div>
            <div class="recap-pos-name">${esc(improved.name)}</div>
          </div>
          <div class="recap-pos-meta">${esc(T.recapImprovedBy(improved.delta))}</div>
        </div>`);
      }
      positiveHtml = `<hr class="recap-divider"><div class="recap-positive">${rows.join('')}</div>`;
    }

    return `
      <div class="week-block anim-week" style="animation-delay:${BASE}ms">
        <div class="sec-label anim-fade-up" style="animation-delay:${BASE+30}ms">${T.weekRange(mon,sun)}</div>
        <div class="card glass">
          ${heroHtml}
          ${lateRows}
          ${skipRows}
          ${trendHtml}
          ${compareHtml}
          ${positiveHtml}
        </div>
      </div>`;
  }).join('');

  requestAnimationFrame(() => {
    setTimeout(() => {
      document.querySelectorAll('.confetti-host').forEach(host => spawnConfetti(host));
      document.querySelectorAll('.anim-trophy').forEach(el => {
        el.addEventListener('animationend', () => { el.classList.add('done'); }, { once: true });
      });
    }, 380);
  });
}

// ════════════════════════════════════════════════════════
//  CALENDAR STATE + RENDER
// ════════════════════════════════════════════════════════
let calYear = new Date().getFullYear(), calMonthIdx = new Date().getMonth();

function calDayScheduled(dateStr, mask) {
  if (!mask || mask === '0000000') return false;
  const dow = new Date(dateStr + 'T12:00:00Z').getUTCDay();
  const idx = dow === 0 ? 6 : dow - 1;
  return mask[idx] === '1';
}

function renderCalendar() {
  if (!data) return;
  const calEl = document.getElementById('cal-grid');
  if (!calEl) return;

  // Day map: date -> {late, skip, attend, mins}
  const dayMap = {};
  (data.entries || []).forEach(e => {
    if (!dayMap[e.date]) dayMap[e.date] = { late:0, skip:0, attend:0, mins:0 };
    const t = e.type || 'late';
    if (t === 'late') { dayMap[e.date].late++; dayMap[e.date].attend++; dayMap[e.date].mins += e.mins; }
    else if (t === 'skip') dayMap[e.date].skip++;
    else if (t === 'attend') dayMap[e.date].attend++;
  });

  // Month label
  const firstOfMonth = new Date(calYear, calMonthIdx, 1);
  const labelEl = document.getElementById('cal-month-label');
  if (labelEl) labelEl.textContent = firstOfMonth.toLocaleDateString(navigator.language, { month:'long', year:'numeric' });

  // Weekday headers (Mon-first)
  const wdEl = document.getElementById('cal-weekdays');
  if (wdEl) {
    // Jan 1 2024 is a Monday — iterate 0-6 for Mon-Sun
    wdEl.innerHTML = Array.from({length:7}, (_,i) =>
      `<div class="cal-wd">${esc(new Date(2024,0,1+i).toLocaleDateString(navigator.language,{weekday:'narrow'}))}</div>`
    ).join('');
  }

  // Grid cells
  const daysInMonth = new Date(calYear, calMonthIdx + 1, 0).getDate();
  const firstWeekday = (firstOfMonth.getDay() + 6) % 7; // Mon=0
  const today = todayStr();

  const gymMask = data.gymDays || '0000000';

  let cells = Array.from({length:firstWeekday}, () => '<div class="cal-cell"></div>').join('');
  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = `${calYear}-${pad(calMonthIdx+1)}-${pad(d)}`;
    const info = dayMap[dateStr];
    const isToday = dateStr === today;
    const isPast = dateStr < today;
    const isScheduled = calDayScheduled(dateStr, gymMask);
    let cls = 'cal-cell' + (isToday ? ' cal-today' : '');
    let style = '', marker = '';
    if (info) {
      cls += ' cal-has-entries';
      if (info.late > 0) {
        const alpha = Math.min(0.48, 0.12 + info.late * 0.09 + info.mins * 0.002).toFixed(2);
        style = `background:rgba(239,68,68,${alpha})`;
        marker = `<span class="cal-dot cal-dot-late">${info.late}</span>`;
        cls += ' cal-late';
      } else if (info.attend > 0) {
        style = `background:rgba(34,197,94,.18)`;
        marker = `<span class="cal-dot cal-dot-attend">&#x2713;</span>`;
        cls += ' cal-attend-only';
      } else if (info.skip > 0) {
        style = `background:rgba(245,158,11,.18)`;
        marker = `<span class="cal-dot cal-dot-skip">&#x2298;</span>`;
      }
    } else if (isScheduled && isPast) {
      marker = `<span class="cal-dot cal-dot-miss">&middot;</span>`;
    } else if (!isScheduled) {
      // Rest day (not a gym day and no entry logged)
      if (isPast || isToday) {
        cls += ' cal-rest-past';
      } else {
        marker = `<span class="cal-dot cal-dot-rest">&ndash;</span>`;
      }
    }
    cells += `<div class="${cls}" data-date="${dateStr}"${style ? ` style="${style}"` : ''}>` +
      `<span class="cal-day-num">${d}</span>${marker}</div>`;
  }
  calEl.innerHTML = cells;
}

// Nav indicator — slides behind the active tab button
function updateNavIndicator() {
  const bar = document.querySelector('.bottom-nav .nav-bar');
  if (!bar) return;
  const indicator = bar.querySelector('.nav-indicator');
  if (!indicator) return;
  const activeBtn = bar.querySelector('.nav-btn.active');
  if (!activeBtn) return;
  const barRect = bar.getBoundingClientRect();
  const btnRect = activeBtn.getBoundingClientRect();
  indicator.style.width  = btnRect.width  + 'px';
  indicator.style.transform = `translateX(${btnRect.left - barRect.left}px)`;
}

// ════════════════════════════════════════════════════════
//  RENDER: PEOPLE
// ════════════════════════════════════════════════════════
function renderPeople() {
  if (!data) return;
  const emEl=document.getElementById('people-empty'), lEl=document.getElementById('people-list');
  if (!data.people.length) { emEl.style.display=''; lEl.innerHTML=''; return; }
  emEl.style.display='none';
  lEl.innerHTML = data.people.map((p,i)=>{
    const isMe = userProfile && p.id === userProfile.userId;
    const streakBadge = (p.streak > 0) ? `<span class="streak-badge">${T.streakLabel(p.streak)}</span>` : '';
    const freezeBadge = (p.freezes > 0) ? `<span class="freeze-badge">❄️ ×${p.freezes}</span>` : '';
    return `<div class="person-row animate" style="animation-delay:${i*35}ms;cursor:pointer" data-uid="${esc(p.id)}">
      ${avatarHtml(p)}
      <div class="person-name">${esc(p.name)}${isMe ? ' <span style="font-size:11px;color:var(--accent-text);font-weight:700">(Du)</span>' : ''}${p.isCreator ? ' <span style="font-size:10px;color:var(--text-3)">★</span>' : ''}</div>
      <div style="display:flex;gap:5px;flex-shrink:0">${streakBadge}${freezeBadge}</div>
    </div>`;
  }).join('');
}

// ════════════════════════════════════════════════════════
//  RENDER: ADMIN PANEL
// ════════════════════════════════════════════════════════
function renderAdminPanel() {
  if (!adminMode) return;
  // Update week toggle label
  const weekLbl = document.getElementById('adm-week-lbl');
  if (weekLbl) weekLbl.textContent = adminShowCurWeek ? T.admWeekOff : T.admWeekOn;
  const weekBtn = document.getElementById('adm-week-btn');
  if (weekBtn) weekBtn.style.opacity = adminShowCurWeek ? '1' : '.7';
  // Show gym coords info
  const coordsEl = document.getElementById('adm-coords-info');
  if (coordsEl) {
    coordsEl.textContent = data?.gymLat != null
      ? `Gym: ${data.gymLat.toFixed(5)}, ${data.gymLng.toFixed(5)} — Radius: ${data.gymRadius}m`
      : '';
  }
}

function renderAll() {
  renderPill(); renderStreakHero(); renderWeek(); renderHistory(); renderCalendar(); renderPeople(); renderGroupsSection(); renderAdminPanel();
}

function renderPill() {
  // pill removed from header — group info lives in People tab
}

