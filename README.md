# Summoner

**Summon any app with a single keystroke.**

Summoner is a lightweight macOS menu bar utility that switches to or launches
applications instantly using a fixed keyboard chord: **⌃⌥⌘** (Control + Option
+ Command) plus a single key you assign. Press **⌃⌥⌘M** and Mail comes to the
front — launching first if it isn't running. Press it again while Mail is
frontmost and it hides.

## Highlights

- **One chord per app** — fixed ⌃⌥⌘ leader, single key (A–Z, 0–9) per binding
- **Zero permissions** — no Accessibility, no Input Monitoring; fully sandboxed
- **Invisible until needed** — menu bar only, no Dock icon
- **Fast** — hotkey to app activation feels instantaneous
- Optional launch at login

## Requirements

- macOS 13 (Ventura) or later
- Xcode to build (no third-party dependencies)

## Building

Open `Summoner.xcodeproj` in Xcode and run the `Summoner` scheme. On first
launch a settings window opens — click **＋ Add App…**, pick an app, and type
the key you want. Bindings save and register immediately.

## How it works

Hotkeys use Carbon's `RegisterEventHotKey`, which works system-wide without
special permissions. Apps are summoned by bundle identifier through
`NSWorkspace`, so bindings survive app relocation. Bindings persist as JSON in
`UserDefaults`.

See [PRODUCT.md](PRODUCT.md) for the full product specification.
