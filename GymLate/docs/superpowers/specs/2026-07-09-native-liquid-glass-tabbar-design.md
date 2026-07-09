# Native Liquid Glass Tab Bar (Apple-Music-Pille)

**Datum:** 2026-07-09 · **Status:** approved (Junus, via Q&A)

## Problem

Junus will in der unteren Nav-Bar die native iOS-26-Interaktion wie bei Apple
Music: eine **Glaspille** (statt der gelben Gradient-Pille), die beim Anfassen
größer wird und beim Sliden unterm Finger von Tab zu Tab gleitet. Die
selbstgebaute `BottomNav` (matchedGeometryEffect) slidet zwar nachweislich,
hat aber weder Glas-Pille noch Drag-Interaktion.

## Entscheidung

**Native `TabView` statt Custom-Bar** (von Junus gewählt). Auf iOS 26 rendert
SwiftUI damit automatisch die echte floating Liquid-Glass-Bar inklusive
Grow-on-Touch, Finger-Tracking und Morph — keine Nachbau-Physik.

## Umsetzung

- `AppRootView`: hinter `#available(iOS 18.0, *)` (die `Tab(_:systemImage:value:)`
  API braucht iOS 18; Deployment-Target ist 17.0) wird der Content in ein
  `TabView(selection: $selectedTab)` mit vier `Tab`s gepackt.
- `GroupPillHeader` bleibt fix über allen Tabs (VStack: Header, dann TabView).
- `GymBackground` muss pro Tab-Content sichtbar bleiben (TabView hostet
  Content separat) — Hintergrund im Tab-Content setzen, falls nötig.
- Akzent: `.tint(K.accentDeep)` — Icon/Label des aktiven Tabs bleibt amber,
  die Pille selbst ist System-Glas.
- iOS 17 (Fallback): bisherige `BottomNav` bleibt unverändert bestehen.
- Sheets, Overlays, Toast, Sync-Logik: unverändert.

## Verifikation

Build für iOS-26.5-Simulator; Video-Aufnahme des Tab-Wechsels (Auto-Cycle-
Debug-Task, wird danach entfernt) → Glaspille sichtbar, slidet nativ.
Die Drag-Grow-Physik ist System-Verhalten und braucht keinen eigenen Test.
