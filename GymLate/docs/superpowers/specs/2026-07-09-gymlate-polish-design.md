# GymLate iOS — Polish & Accessibility Pass

**Date:** 2026-07-09  
**Scope:** Single PR covering four areas: color-blind accessibility, Recap screen expansion, consistency pass, details & polish.  
**Deployment target:** iOS 18+ (Swift Charts available).

---

## 1. Color-Blind Accessibility

### History calendar cells (`HistoryView.dayCell`)

Three encoding layers per cell — color (existing) + text glyph (existing) + **shape (new)**:

| State | BG fill | Glyph | New shape |
|-------|---------|-------|-----------|
| Late | `K.red.opacity(alpha)` | count number | Zigzag border overlay, 3pt stroke, `K.red` |
| Attend | `K.green.opacity(0.18)` | "✓" | Thin solid border, 1.5pt, `K.green` |
| Skip | `K.gold.opacity(0.18)` | "⊘" | No border |
| Missed | none | "·" grey | No border |

**`ZigzagBorder` shape** — new `Shape` added to `Extensions.swift`:
- Draws a closed sawtooth path around the cell rect.
- Tooth amplitude ≈ 3pt; tooth count computed from perimeter so density stays consistent at all cell sizes.
- Applied as `.overlay { ZigzagBorder().stroke(K.red, lineWidth: 3) }` on late cells only.

### Other red/green signals — no changes needed

- `EntryBadge`: text + color ("✓", "N min.", "⊘ reason") — redundant already.
- `WeekView` stat strip: late count is a number in red — number is the non-color signal.
- `PersonRow` streak: `Label("N", systemImage: "flame.fill")` — icon + number.
- `ProfileView` `StatBadge`: icon + number + label.

---

## 2. Recap Screen Expansion

All additions sit inside each `WeekBlock`'s existing `glassCard()`, below the ranked rows, separated by `Divider()`. The block remains fully scrollable.

### Card A — Weekly Trend Bar Chart

- Swift Charts `Chart` with one `BarMark` per day of the week (Mon–Sun).
- X-axis: `K.L.dayNames` abbreviations. Y-axis: total late minutes that day across all members.
- Bar fill: `K.red.opacity(0.7)`. Chart height: 120pt.
- Zero-minute days: 2pt ghost bar so all 7 columns are always visible.
- Accessibility: `.accessibilityLabel("Monday, 12 minutes late")` per bar.

### Card B — Week-over-Week Comparison

- Always shown. Compares total late minutes in this `WeekBlock` vs. the previous one. Since `blocks` is sorted descending by date, the previous week for index `i` is at `blocks[i+1]` — use `ForEach(Array(blocks.enumerated()))` in the body to get the index.
- Display: delta string (e.g. "−14 min") + SF Symbol arrow + one-line verdict.

| Delta | Symbol | Verdict |
|-------|--------|---------|
| Negative (better) | `arrow.down` | "Better than last week" |
| Zero | `arrow.right` | "Same as last week" |
| Positive (worse) | `arrow.up` | "Worse than last week" |
| No previous week | `—` | "First recorded week" (greyed out) |

Arrow direction is the primary (shape) signal; color is secondary.

### Card C — Positive Cards

**Most Punctual** (always shown if ≥1 attend entry exists in the week):
- Person with the most `type == "attend"` entries.
- Display: "🏅 Most Punctual — Alex · 3 check-ins". Avatar via `AvatarView` (person lookup by name).

**Most Improved** (shown only when a previous week exists AND the person reduced their late minutes):
- Person with the largest reduction in late minutes vs. previous week.
- Display: "📈 Most Improved — Sam · −8 min vs last week". Avatar via `AvatarView`.

If neither card applies, Card C is omitted entirely.

---

## 3. Consistency Pass

### Avatar unification

`WeekView/EntryRow`, `RecapView/rankRow`, and `CalDayDetailSheet` currently show initials on a yellow gradient circle. All three switch to `AvatarView`.

**Lookup helper** (private, added where needed):
```swift
func person(named: String) -> Person? {
    appState.groupData?.people.first {
        $0.name.lowercased() == named.lowercased()
    }
}
```

- `WeekView/EntryRow` and `RecapView/rankRow`: call helper at render time (both have `appState` via `@EnvironmentObject`).
- `CalDayDetailSheet`: receives an optional `[Person]` array passed from `HistoryView` (which has `appState`). Falls back to initials-on-yellow-gradient if no match (deleted members whose entries still exist).

### Home tab rename

- `K.L.navWeek` → `K.L.navHome` = `"Home"` (identical in DE and EN).
- Tab icon: `"calendar"` → `"house.fill"` in both `nativeTabView` and `BottomNav.navItem`.
- `AppTab.week` enum case name unchanged (internal; env-var hook `default: return .week` continues to work).
- Section header inside the tab (`lblWeek` = "Diese Woche" / "This Week") unchanged.

### Design tokens

- Add `K.cornerRadius: CGFloat = 12` as canonical card corner radius.
- Update the handful of inline `RoundedRectangle(cornerRadius: 10)` and `cornerRadius(16)` calls on card-shaped surfaces to use `K.cornerRadius`.
- No other token extraction — existing `Theme` typography and `glassCard()` are already consistent.

---

## 4. Details & Polish

### Leave Group safety

**`SettingsSheet`:**
- Add `@State private var confirmLeave = false`.
- Existing `Button(K.L.leaveGroup, role: .destructive)` sets `confirmLeave = true` instead of calling `leaveCurrentGroup()` directly.
- Add `.confirmationDialog(K.L.confirmLeave, isPresented: $confirmLeave, titleVisibility: .visible)` with a destructive confirm button and a cancel button.

**`PeopleView`:**
- Remove the standalone "Leave Group" button (lines 99–110). Leave Group remains accessible via Settings (gear icon) and via tapping own avatar → `ProfileView` (already has confirmation).

### Streak celebration animation

In `StreakHero`:
- Add `@State private var scale: CGFloat = 1.0` and `@State private var didAnimate = false`.
- `.onChange(of: extendedToday)`: when it becomes `true` and `!didAnimate`:
  - **Normal motion**: `withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1.18 }` then after 0.3s `withAnimation { scale = 1.0 }`. Apply `.scaleEffect(scale)` to the flame + number group. Also animate shadow radius: 12 → 28 → 12.
  - **Reduce Motion**: skip scale; cross-fade the flame color change via `.animation(.easeInOut(duration: 0.4), value: extendedToday)` (already works since color is driven by `extendedToday`).
  - Set `didAnimate = true` after firing.

### Empty states — no changes

All existing empty states (`WeekView`, `RecapView`, `PeopleView`) are adequate. New-group state is covered by `PeopleView`'s existing empty-people view.

### Dynamic Type + VoiceOver (targeted fixes)

| Location | Fix |
|----------|-----|
| `StreakHero` button | `.accessibilityLabel("\(streak) day streak\(extendedToday ? ", extended today" : ", tap to check in")")` |
| `HistoryView.dayCell` buttons | `.accessibilityLabel` per state: "Late, N times", "On time", "Skipped", "Missed" |
| Recap chart bars | `.accessibilityLabel("Monday, 12 minutes late")` per bar |
| `AppHeader` gear button | `.accessibilityLabel("Settings")` |
| `AppHeader` avatar button | `.accessibilityLabel("My profile")` |

---

## Files touched

| File | Changes |
|------|---------|
| `Extensions.swift` | Add `ZigzagBorder` shape |
| `HistoryView.swift` | `dayCell`: zigzag + solid border overlays; pass `[Person]` to `CalDayDetailSheet`; a11y labels |
| `RecapView.swift` | Add Chart A, B, C cards; switch `rankRow` to `AvatarView` |
| `WeekView.swift` | `EntryRow`: switch to `AvatarView`; `StreakHero`: celebration animation + a11y label |
| `PeopleView.swift` | Remove standalone Leave Group button |
| `SettingsSheet.swift` | Add confirmation dialog to Leave Group |
| `AppRootView.swift` | Rename Week → Home tab; house.fill icon; a11y labels on header buttons |
| `Constants.swift` | Add `K.L.navHome`, `K.cornerRadius`; update inline corner radius usages |
| `Theme.swift` | No changes |
| `AvatarView.swift` | No changes |
