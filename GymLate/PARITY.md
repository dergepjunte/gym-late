# Website ↔ iOS Parity Checklist

Structural comparison of the reference web app (`../index.html`) against the
SwiftUI app. Colors intentionally differ: the iOS app uses the yellow Liquid
Glass theme, the website stays purple.

| Website feature | iOS status |
|---|---|
| Week: streak hero with grey vs. lit flame states | ⚠️ Partial — `StreakCard` shows the number, no lit/grey "extended today" state |
| Week: check-in time hero (`fixedCheckinEnabled`) | ❌ Missing — fields exist in `GroupData` but unused |
| Week: stat row (late count / total minutes cards) + skip chip | ❌ Missing — text summary only |
| Week: log entry CTA | ✅ Present (inline gradient button instead of FAB — acceptable) |
| History: month calendar grid + day detail modal | ❌ Missing — iOS shows week summary cards instead |
| Recap: week blocks with ranking list | ⚠️ Different — iOS reuses the Wrapped story slides |
| People: members list with profile modal | ✅ Present |
| People: invite card with copy-code button | ✅ Added in this pass |
| People: my groups list + switcher | ✅ Present |
| People: leave group | ✅ Present (lives in Settings sheet) |
| People: admin panel UI | ❌ Missing (`LocalStore.adminPassword` exists but unused) |
| Modals: create/join group, profile setup, login, settings | ✅ Present |
| Modals: edit/delete entry (admin) | ❌ Missing (`APIClient.deleteEntry` has no call site) |
| Modals: chest reward | ⚠️ Different — iOS uses a toast (acceptable) |
| Settings: gym location map picker (Leaflet on web) | ❌ Missing on iOS |
| Overlays: Wrapped weekly story | ✅ Present |
| Overlays: daily hype | ✅ Present |
| Overlays: geo check-in prompt | ✅ Present |
| Overlays: late animation, streak animation | ❌ Missing |

Legend: ✅ parity · ⚠️ present but different · ❌ missing on iOS
