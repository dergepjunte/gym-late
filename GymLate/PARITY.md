# Website ↔ iOS Parity Checklist

Structural comparison of the reference web app (`../index.html`) against the
SwiftUI app. Colors intentionally differ: the iOS app uses the yellow Liquid
Glass theme, the website stays purple. Last full audit: 2026-07-09.

## Struktur (Screens & Navigation)

| Website | iOS status |
|---|---|
| Bottom nav: 4 tabs Woche/Verlauf/Rückblick/Personen | ✅ Same tabs, same order (native Liquid Glass TabView on iOS 18+) |
| Nav icons: Kalender / Kalender-Punkte / Balkendiagramm / Personen(2) | ⚠️ iOS uses SF Symbols; Rückblick is `star.fill` instead of a bar chart |
| **Verlauf tab = Monatskalender + Tag-Detail-Modal** | ❌ iOS Verlauf shows week summary cards instead — the calendar is missing entirely |
| **Rückblick tab = Wochen-Blöcke mit Ranking** | ⚠️ Swapped: iOS shows the week blocks under *Verlauf* and Wrapped-style story slides under *Rückblick* |
| Header: 🏋️ logo + „GymLate" + gear + my-profile avatar button | ⚠️ iOS header is group-pill + name + gear; no branding, no avatar shortcut to own profile |
| Group pill: name · code, tap-to-copy, switch button | ⚠️ iOS pill shows code only (name sits in the header middle); copy lives in Personen invite card |
| FAB „+" on Woche **and** Verlauf | ⚠️ iOS: inline CTA button on Woche only (acceptable per UX direction) |
| i18n: de + en via `navigator.language` | ❌ iOS is German-only (`K.L` hardcoded) |

## Woche

| Website feature | iOS status |
|---|---|
| Streak hero with grey vs. lit flame states + hint text | ⚠️ Partial — `StreakCard` shows avatar + number, no lit/grey "extended today" state |
| Check-in time hero (`fixedCheckinEnabled`) | ❌ Missing — fields exist in `GroupData` but unused |
| Stat row (late count / total minutes cards) + skip chip | ❌ Missing — "N Verspätungen" text only |
| Entry list with localized dates („Mo., 6. Juli") | ⚠️ iOS `EntryRow` shows raw ISO dates („2026-07-09") |
| Log entry CTA | ✅ Present (inline gradient button instead of FAB — acceptable) |

## Personen

| Website feature | iOS status |
|---|---|
| Members list with profile modal | ✅ Present |
| Photo avatars (`avatarImg`, upload + NSFW check on web) | ❌ Model has `avatarImg` but no view renders it; no upload on iOS — web photo avatars fall back to emoji |
| Profile modal: gym-day chips | ❌ Missing on iOS profile |
| Invite card with copy-code button | ✅ Present |
| My groups list + switcher | ✅ Present |
| „Gruppe erstellen" inside the app (People pane + switcher modal) | ❌ iOS offers only „Gruppe beitreten" in-app; create exists on Landing only |
| Leave group | ✅ Present (Settings sheet + own profile) |
| Admin panel UI (incl. landing admin login, test group) | ❌ Missing (`LocalStore.adminPassword` exists but unused) |

## Modals & Settings

| Website feature | iOS status |
|---|---|
| Create/join group, profile setup, recovery login, recovery-code reveal | ✅ Present |
| Log entry: attend/late/skip modes, person, date, mins, reason | ✅ Present |
| Edit/delete entry (admin) | ❌ Missing (`APIClient.deleteEntry` has no call site) |
| Chest reward | ⚠️ Different — iOS uses a toast (acceptable) |
| Settings: gym days (creator) + my available days + lock hint | ✅ Present (lock surfaces as error text) |
| Settings: gym location map picker + radius (Leaflet on web) | ❌ Missing on iOS (MapKit imported but unused) |
| Settings: fixed check-in time toggle (BETA) | ❌ Missing |
| Settings: geo check-in toggle + „Standort testen" | ❌ Missing — geo prompt itself works, but users can't opt out on iOS |
| Edit profile: name, emoji, color | ✅ Present (no photo upload, see above) |

## Overlays

| Website feature | iOS status |
|---|---|
| Wrapped weekly story | ✅ Present |
| Daily hype | ✅ Present |
| Geo check-in prompt | ✅ Present |
| Late animation, streak animation | ❌ Missing |

Legend: ✅ parity · ⚠️ present but different · ❌ missing on iOS
