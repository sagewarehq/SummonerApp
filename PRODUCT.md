# Summoner — Product Specification

**Version:** 1.0 (MVP)
**Platform:** macOS 13+ (Ventura and later)
**Bundle ID:** `io.sageware.Summoner`
**Author:** Jesse Panganiban / Sageware Solutions
**Status:** Draft

---

## 1. Overview

Summoner is a lightweight macOS menu bar utility that lets the user switch to or launch applications instantly using a fixed keyboard chord: a **leader** (⌃⌥⌘ / Control + Option + Command) plus a single user-assigned key.

Example: pressing **⌃⌥⌘ + M** activates Mail — launching it if it isn't running, or bringing it to the front if it is.

### Design principles

1. **Simple above all.** One fixed leader, one key per app, one settings window, nothing else.
2. **Invisible until needed.** Lives in the menu bar; no Dock icon, no windows unless the user opens Settings.
3. **Zero friction.** No Accessibility or Input Monitoring permissions. Works out of the box, sandboxed.
4. **Fast.** Hotkey press to app activation should feel instantaneous (< 100 ms perceived).

---

## 2. Goals & Non-Goals

### Goals (MVP)

- Register global hotkeys of the form ⌃⌥⌘ + `<key>` that work system-wide, regardless of the focused application.
- On trigger: launch the target app if not running, otherwise activate (bring to front).
- Provide a minimal settings UI to add, edit, and remove app-to-key bindings.
- Persist bindings across restarts.
- Optional launch-at-login.

### Non-Goals (MVP)

- Configurable leader key (leader is hard-coded to ⌃⌥⌘).
- Window-level switching (Summoner targets applications, not individual windows).
- Two-stroke / sequence hotkeys, chorded panels, or fuzzy search overlays.
- Scripting, URL schemes, or automation hooks.
- Per-app options (e.g., open specific documents, pass arguments).
- Multi-profile or per-workspace binding sets.
- App Store distribution (personal use; direct build/run from Xcode).

---

## 3. Functional Requirements

### FR-1: Global hotkey registration

- **FR-1.1** — The app registers one global hotkey per binding using the Carbon `RegisterEventHotKey` API with the fixed modifier mask ⌃⌥⌘ (`controlKey | optionKey | cmdKey`).
- **FR-1.2** — Allowed trigger keys: letters A–Z and digits 0–9 (single character).
- **FR-1.3** — Hotkeys are (re)registered on app launch and whenever bindings change; stale registrations are unregistered first.
- **FR-1.4** — If registration for a key fails (e.g., reserved by the system), the failure is surfaced in the Settings UI on that binding's row.

### FR-2: App activation ("summoning")

- **FR-2.1** — On hotkey trigger, resolve the target app by **bundle identifier** via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`.
- **FR-2.2** — Open/activate via `NSWorkspace.shared.openApplication(at:configuration:)` with `activates = true`. This single call handles both launch-if-not-running and activate-if-running.
- **FR-2.3 (toggle behavior)** — If the target app is already the frontmost application (`NSWorkspace.shared.frontmostApplication`), hide it instead of re-activating. Pressing the chord repeatedly toggles the app in and out.
- **FR-2.4** — If the bundle ID cannot be resolved (app uninstalled/moved), fail silently on trigger, but flag the binding row in Settings as "App not found."

### FR-3: Binding management

- **FR-3.1** — The user can add a binding by picking an app (`NSOpenPanel`, directory scoped to `/Applications`, file type `.app`) and typing a trigger key.
- **FR-3.2** — The user can change the trigger key of an existing binding inline.
- **FR-3.3** — The user can remove a binding.
- **FR-3.4 (validation)** — Duplicate trigger keys are rejected: the conflicting row is highlighted and the new key is not saved until unique. Invalid characters (anything outside A–Z, 0–9) are rejected on input.
- **FR-3.5** — Bindings are keyed by bundle identifier, not filesystem path, so they survive app relocation.

### FR-4: Persistence

- **FR-4.1** — Bindings are stored as JSON-encoded `Codable` data in `UserDefaults` (suite: standard).
- **FR-4.2** — Bindings load on launch before hotkey registration.
- **FR-4.3** — Malformed/undecodable stored data resets to an empty binding list (no crash).

### FR-5: Menu bar presence

- **FR-5.1** — The app runs as a menu bar agent (`LSUIElement = YES`): no Dock icon, no ⌘Tab entry.
- **FR-5.2** — The menu bar icon uses an SF Symbol (e.g., `wand.and.stars` or `keyboard`).
- **FR-5.3** — The menu shows: a read-only quick-reference list of current bindings ("⌃⌥⌘M — Mail"), a **Settings…** item, and **Quit**.
- **FR-5.4** — Opening Settings activates the app (`NSApp.activate(ignoringOtherApps: true)`) so the window appears in front.

### FR-6: Launch at login

- **FR-6.1** — A "Launch at login" toggle in Settings, implemented with `SMAppService.mainApp.register()` / `.unregister()`.
- **FR-6.2** — The toggle reflects actual registration status on open (`SMAppService.mainApp.status`).

---

## 4. User Interface Specification

### 4.1 Menu bar menu

```
┌──────────────────────────┐
│  ⌃⌥⌘M   Mail             │   (disabled, informational)
│  ⌃⌥⌘S   Slack            │
│  ⌃⌥⌘G   Ghostty          │
│  ──────────────────────  │
│  Settings…               │
│  Quit Summoner           │
└──────────────────────────┘
```

### 4.2 Settings window

Single window, fixed size (~460 × 380), no tabs.

```
┌─ Summoner Settings ──────────────────────────────┐
│                                                  │
│  Leader key:  ⌃ ⌥ ⌘  (fixed)                     │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │ [icon] Mail            ⌃⌥⌘ + [ M ]  (–)  │    │
│  │ [icon] Slack           ⌃⌥⌘ + [ S ]  (–)  │    │
│  │ [icon] Ghostty         ⌃⌥⌘ + [ G ]  (–)  │    │
│  └──────────────────────────────────────────┘    │
│                                                  │
│  ( + Add App… )                                  │
│                                                  │
│  ☐ Launch at login                               │
│                                                  │
└──────────────────────────────────────────────────┘
```

Row anatomy:

| Element | Behavior |
|---|---|
| App icon + name | Read-only; icon fetched via `NSWorkspace.shared.icon(forFile:)` |
| Key field | Single-character text field; uppercased on input; validates A–Z/0–9 and uniqueness |
| Remove (–) | Deletes the binding immediately (no confirmation — it's one keystroke to re-add) |
| Error state | Red border + tooltip on the row for duplicate key, failed registration, or app not found |

### 4.3 Add flow

1. Click **Add App…** → `NSOpenPanel` opens at `/Applications`, filtered to `.app` bundles.
2. On selection, a new row appears with an empty key field, focused.
3. User types one character → binding saved, hotkey registered live. No separate save button anywhere.

---

## 5. Technical Architecture

### 5.1 Stack

| Concern | Choice |
|---|---|
| Language / UI | Swift 5.9+, SwiftUI (`MenuBarExtra` + `Settings` scenes) |
| Hotkeys | Carbon `RegisterEventHotKey` + `InstallEventHandler` (no third-party dependencies) |
| App activation | AppKit `NSWorkspace` |
| Persistence | `UserDefaults` + `Codable` JSON |
| Login item | `ServiceManagement` (`SMAppService`) |
| Sandbox | App Sandbox **enabled** (all APIs used are sandbox-compatible) |
| Permissions | None required (no Accessibility, no Input Monitoring) |

### 5.2 Components

```
SummonerApp (App / @main)
 ├── MenuBarExtra ──────────── menu content (bindings list, Settings, Quit)
 ├── Settings scene ─────────── SettingsView
 │
 ├── BindingStore (ObservableObject)
 │     • bindings: [AppBinding]
 │     • load()/save() ⇄ UserDefaults
 │     • add/update/remove → triggers HotkeyManager.reload
 │
 ├── HotkeyManager
 │     • register(bindings:) — Carbon RegisterEventHotKey per binding
 │     • single installed event handler: hotkeyID → binding lookup
 │     • unregisterAll()
 │
 └── AppSummoner
       • summon(bundleID:) — frontmost check → hide, else openApplication(activates:)
```

### 5.3 Data model

```swift
struct AppBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleID: String     // e.g. "com.apple.mail" — source of truth
    var appName: String      // display cache, e.g. "Mail"
    var key: String          // single char, uppercase, A–Z or 0–9
}
```

Stored under `UserDefaults` key `io.sageware.Summoner.bindings` as JSON.

### 5.4 Hotkey ID scheme

Each Carbon hotkey needs a stable `EventHotKeyID`. Use a monotonically increasing `UInt32` assigned at registration time, held in a `[UInt32: AppBinding]` dictionary inside `HotkeyManager`. The dictionary is rebuilt on every reload; IDs never persist.

### 5.5 Key code mapping

Carbon requires virtual key codes, not characters. Include a static `[Character: UInt32]` table for A–Z and 0–9 (ANSI layout key codes, e.g. `M → 46`, `S → 1`). This is the one fiddly part of the implementation; the table is ~36 entries and fixed.

---

## 6. Edge Cases & Error Handling

| Case | Behavior |
|---|---|
| Trigger key already used by another binding | Reject input; highlight conflicting row |
| System/other app already owns ⌃⌥⌘+key globally | `RegisterEventHotKey` returns error → flag row "Shortcut unavailable" |
| Target app uninstalled | Trigger is a no-op; row flagged "App not found" on next Settings open |
| Same app added twice | Allowed technically, but Add flow pre-checks bundle ID and focuses the existing row instead |
| App is frontmost when summoned | Hide it (toggle behavior, FR-2.3) |
| Corrupt persisted data | Reset to empty list, log to console |
| Settings window opens behind other apps | Prevented via `NSApp.activate(ignoringOtherApps: true)` before showing |

---

## 7. Out of Scope, Possible Future

Listed only to record intent; none of these gate the MVP.

- Configurable leader (would introduce shortcut-recorder UI and the KeyboardShortcuts package).
- Cycle-windows-of-app on repeated press instead of hide.
- Import/export bindings as JSON file (dotfile-friendly).
- iCloud/defaults sync across Macs.
- "Summon last app" chord (⌃⌥⌘ + Tab-like behavior).
- Sparkle-based updates if ever distributed.

---

## 8. Acceptance Criteria (MVP done when…)

1. Fresh build launches to menu bar only; no Dock icon.
2. Adding Mail with key **M**, pressing ⌃⌥⌘M from any app launches/activates Mail in < ~100 ms perceived.
3. Pressing ⌃⌥⌘M while Mail is frontmost hides Mail.
4. Bindings survive quit + relaunch.
5. Duplicate key entry is visibly rejected.
6. Launch-at-login toggle works across a logout/login cycle.
7. No permission prompts appear at any point.
