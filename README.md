# Blablabla

Native macOS dictation app inspired by Wispr Flow.

## What it does

- Global shortcut: `Option + Shift + ISO Section` by default.
- Hold once: push-to-talk.
- Double tap: locks dictation until you press the shortcut again.
- Streams microphone audio to AssemblyAI Universal Streaming v3.
- Pastes the final transcript into the currently focused editable input when possible.
- If no editable input is focused, saves the transcript in the app history window.

## Project structure

- `project.yml`: XcodeGen project definition.
- `Sources/App`: Swift/AppKit/SwiftUI source files.
- `Resources/Info.plist`: macOS app metadata and microphone usage text.

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Run locally

1. Generate the Xcode project:

```bash
xcodegen generate
```

2. Build from Terminal:

```bash
xcodebuild -project Blablabla.xcodeproj -scheme Blablabla -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

3. Open the generated app:

```bash
open build/Build/Products/Debug/Blablabla.app
```

You can also open `Blablabla.xcodeproj` in Xcode and run it there.

## First launch checklist

1. Paste your AssemblyAI API key in the app window.
2. Grant microphone permission.
3. Grant Accessibility permission.
4. Grant Input Monitoring permission.
5. Restart the app after macOS finishes granting the permissions.

## Shortcut note

The default key code assumes an ISO keyboard, meaning the key physically next to `Z` on many Spanish Mac keyboards.

If your keyboard layout differs, update the default key in `SettingsStore.swift`.

## Current insertion strategy

- First tries Accessibility-based text replacement when the focused control exposes a selected text range.
- Falls back to clipboard + simulated `Cmd+V` when necessary.

## Known limitations

- Some secure or custom inputs may reject both direct AX insertion and simulated paste.
- The clipboard fallback temporarily replaces the current plain-text clipboard content before restoring it.
- For a distributed production app, you would usually move temporary token generation to your own backend instead of storing an AssemblyAI key locally.
