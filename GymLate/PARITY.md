# Website ↔ iOS Parity Checklist

Structural comparison of the reference web app (`../index.html`) against the
SwiftUI app. Colors intentionally differ: the iOS app uses the yellow Liquid
Glass theme, the website stays purple. Last full audit: 2026-07-09;
gap-closing pass same day.

## Struktur (Screens & Navigation)

| Website | iOS status |
|---|---|
| Bottom nav: 4 tabs Woche/Verlauf/Rückblick/Personen | ✅ Same tabs, same order (native Liquid Glass TabView on iOS 18+) |
| Nav icons: Kalender / Kalender-Punkte / Balkendiagramm / Personen(2) | ✅ SF equivalents: calendar / calendar.badge.clock / chart.bar.fill / person.2.fill |
| Verlauf tab = Monatskalender + Tag-Detail-Modal | ✅ Month grid with web coloring rules, day-detail sheet, FAB |
| Rückblick tab = Wochen-Blöcke mit Ranking | ✅ Week blocks: ★ hero, rank list by minutes, skip rows |
| Header: 🏋️ logo + „GymLate" + gear + my-profile avatar button | ✅ Incl. 5×-tap admin unlock on the logo |
| Group pill: name · code, tap-to-copy, switch button | ✅ |
| FAB „+" on Woche **and** Verlauf | ✅ Verlauf has the FAB; Woche keeps the inline CTA (dashboard UX direction) |
| i18n: de + en via `navigator.language` | ✅ `K.L` switches on the system locale |

## Woche

| Website feature | iOS status |
|---|---|
| Streak hero with grey vs. lit flame states + hint text | ✅ Grey/lit flame, „Jetzt einchecken →" / „Heute verlängert!", tap opens log sheet |
| Check-in time hero (`fixedCheckinEnabled`) | ✅ Shows today's time, inline editor (any member) |
| Stat row (late count / total minutes cards) + skip chip | ✅ |
| Entry list with localized dates + initials avatars | ✅ |
| Log entry CTA | ✅ Inline gradient button (acceptable per UX direction) |
| Check-in ceremony: late-anim → streak-anim → chest | ✅ Incl. fixed-time ±10-min window converting attend→late |

## Personen

| Website feature | iOS status |
|---|---|
| Members list with profile modal | ✅ |
| Photo avatars (`avatarImg`) | ✅ Rendered everywhere via `AvatarView`; upload/remove in Edit Profile (server enforces the NSFW check) |
| Profile modal: gym-day chips | ✅ Group mask ∩ personal availability |
| Invite card with share button | ✅ ShareLink like the web share flow |
| My groups list + switcher | ✅ |
| „Gruppe beitreten" + „Gruppe erstellen" inside the app | ✅ People tab + group switcher |
| Leave group (red button in the tab) | ✅ Plus Settings + own profile |
| Admin panel UI | ✅ Test data, current-week toggle, Wrapped replay, force hype/geo, clear flags, exit |

## Modals & Settings

| Website feature | iOS status |
|---|---|
| Create/join group, profile setup, recovery login, recovery-code reveal | ✅ |
| Log entry: attend/late/skip modes, person, date, mins, reason | ✅ |
| Edit/delete entry (admin) | ✅ Buttons on week rows, EditEntrySheet via PATCH /entries |
| Admin member edit (streak/freezes/avail days, no lock) | ✅ Slider button on people rows |
| Chest reward | ✅ Chest overlay (❄️/🎁) instead of toast |
| Settings: gym days (creator) + my available days + lock error | ✅ |
| Settings: gym location map picker + radius | ✅ MapKit (tap to pin, radius slider, locate me) |
| Settings: fixed check-in time toggle (BETA) | ✅ |
| Settings: geo check-in toggle + „Standort testen" | ✅ Toggle gates the geo prompt; test shows distance |
| Edit profile: name, emoji, color, photo | ✅ Web avatar lists (single 🏋️ emoji, 10 colors) |

## Overlays

| Website feature | iOS status |
|---|---|
| Wrapped weekly story | ✅ |
| Daily hype (incl. fixed-time set/display section) | ✅ |
| Geo check-in prompt (gym-day + no-gym-day variants) | ✅ |
| Late animation, streak animation | ✅ |

Legend: ✅ parity · ⚠️ present but different · ❌ missing on iOS
