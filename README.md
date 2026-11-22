# Kuarasy

A small macOS menu bar app for working across time zones. *Kuarasy* is the Guarani word for the sun.

It answers two questions:

1. **When is a good time to meet?** The bar across your day is green where everyone is in working hours, yellow where nobody is asleep, and red where someone is.
2. **What time is that for me?** Drag the bar's knob until a coworker's row reads the time they mentioned ("11am EST"), and your row shows your local time.

Kuarasy lives in the menu bar (look for the sun) and has no Dock icon.

## Requirements

- macOS 14 or newer, on Apple Silicon or Intel.
- Liquid Glass appears on macOS 26 and later. Older systems get a translucent material instead.

## Install

### Download a build

1. Download `Kuarasy-<version>.dmg` from the [latest release](https://github.com/kauelima/kuarasy/releases/latest).
2. Open the DMG and drag **Kuarasy** into **Applications**.
3. Open Kuarasy from Applications.

Builds aren't signed with an Apple Developer ID, so macOS blocks the first launch with a message that Apple can't check the app for malicious software. To allow it:

1. Try to open Kuarasy once and dismiss the warning.
2. Go to **System Settings > Privacy & Security**, scroll to the Security section and click **Open Anyway** next to the Kuarasy message.
3. Confirm with your password. macOS remembers the choice, so later launches open normally.

Or remove the download flag from the terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Kuarasy.app
```

### Build from source

Needs Xcode 26 or newer.

```sh
git clone https://github.com/kauelima/kuarasy.git
cd kuarasy
xcodebuild -project Kuarasy.xcodeproj -scheme Kuarasy -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' build
cp -R build/Build/Products/Release/Kuarasy.app /Applications/
```

This builds a universal app (Apple Silicon and Intel). Apps built on your own Mac aren't flagged as downloads, so it opens without the security prompt.

## Using it

- **+** adds a location. Search by city, abbreviation (`EST`, `BRT`) or offset (`+5:30`). After picking one you can give it a label such as "Design Team".
- Rows above the bar count toward it. Rows below it are compact reference clocks: they follow the bar's time but don't change its colours. Drag rows to reorder them, or drag a row across the bar to switch it.
- Hover a row for the **⋯** menu: show in menu bar, count or stop counting toward the bar, edit, remove.
- Under the bar, **‹ ›** move 30 minutes within today and **Now** returns to live time. The green range at the top right is today's longest shared working window. Click it to jump there.
- **Settings** (gear, top right): your own time zone, 12h or 24h time, open at login, what the menu bar shows, working days and hours, sleeping hours, and Quit.

## Development

Open `Kuarasy.xcodeproj` and press ⌘R, or build and launch from the terminal:

```sh
Scripts/run.sh
```

Run the tests:

```sh
xcodebuild -project Kuarasy.xcodeproj -scheme Kuarasy -destination 'platform=macOS' test
```

### Preview window

Debug builds accept `--preview <list|add|edit|settings>` to open the popover content in a normal window, which is easier to inspect and screenshot than the menu bar popover. Two optional flags go with it:

- `--demo` uses sample locations and leaves your saved ones alone.
- `--scrub` moves the bar to 15:00 today instead of the live time.

```sh
Scripts/run.sh --preview settings --demo
```

### Project layout

```
Kuarasy/
  KuarasyApp.swift        MenuBarExtra scene, app delegate, debug preview
  Models.swift            Location, WorkingHours, AppSettings, status enums
  ClockStore.swift        @Observable state, UserDefaults persistence, minute ticker
  TimeMath.swift          pure time calculations
  TimeZoneCatalog.swift   searchable zones and abbreviation map
  TimeFormat.swift        display formatting
  LaunchAtLogin.swift     SMAppService wrapper
  Views/                  SwiftUI panels and the glass helpers
KuarasyTests/             Swift Testing suites for TimeMath, the catalog and ClockStore
Scripts/run.sh            Debug build and launch
```

The Xcode project uses synchronized folders, so any file added under `Kuarasy/` or `KuarasyTests/` is built automatically.

## Roadmap

See [FUTURE.md](FUTURE.md) for what's planned next.
