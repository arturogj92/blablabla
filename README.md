<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Blablabla icon">
</p>

<h1 align="center">Blablabla</h1>

<p align="center">
  Native macOS dictation app powered by AssemblyAI real-time streaming.<br>
  Open source. No subscriptions. Your API key, your data.
</p>

---

## Features

- **Push-to-talk** — hold your shortcut key to dictate, release to stop
- **Locked dictation** — double-tap the shortcut to keep recording hands-free
- **Fn key support** — optionally use the Fn key alone as push-to-talk
- **Auto-paste** — transcript is inserted directly into whatever app has focus
- **Multi-language** — uses AssemblyAI's multilingual model, auto-detects language
- **Floating dock tab** — minimal waveform pill that follows your focused screen
- **Transcript history** — searchable, paginated, with copy button
- **Configurable sounds** — pick from 13 system sounds for start/lock/stop
- **Local usage tracking** — sessions and duration counter
- **Dark UI** — custom dark theme with collapsible sidebar

## Screenshots

<p align="center">
  <em>(coming soon)</em>
</p>

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- An [AssemblyAI](https://www.assemblyai.com) API key (free tier: $50 credit + 10h/month)

## Quick start

### 1. Install XcodeGen (if you don't have it)

```bash
brew install xcodegen
```

### 2. Clone and generate the project

```bash
git clone https://github.com/arturogj92/blablabla.git
cd blablabla
xcodegen generate
```

### 3. Build and run

**Option A — Terminal:**

```bash
xcodebuild -project Blablabla.xcodeproj -scheme Blablabla -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Blablabla-*/Build/Products/Debug/Blablabla.app
```

**Option B — Xcode:**

```bash
open Blablabla.xcodeproj
```

Then hit `Cmd+R` to build and run.

## First launch

1. Paste your **AssemblyAI API key** in Settings
2. Grant **Microphone** permission
3. Grant **Accessibility** permission
4. Grant **Input Monitoring** permission
5. Restart the app after granting permissions

## How it works

| Action | What happens |
|--------|-------------|
| **Hold shortcut** | Push-to-talk — records while held, stops on release |
| **Quick double-tap** | Locks dictation — keeps recording until you tap again |
| **Tap while locked** | Stops recording and transcribes |
| **Hold Fn** (if enabled) | Same as push-to-talk with the Fn key alone |
| **Click dock pill** | Toggle recording on/off |

The transcript is automatically pasted into the focused text field. If no editable field is found, it's saved to history.

## Default shortcut

`Option + Shift + § (ISO Section)`

This is the key next to `Z` on ISO keyboards (common on Spanish/European Mac keyboards). You can change it in Settings > Shortcut > Record.

## Project structure

```
Sources/App/
├── AppDelegate.swift          # App lifecycle, shortcut & Fn monitors
├── AppModel.swift             # State machine, recording logic
├── BlablablaApp.swift         # SwiftUI entry point
├── Models/
│   ├── AudioDevice.swift
│   └── TranscriptRecord.swift
├── Services/
│   ├── AssemblyAIStreamingClient.swift   # WebSocket streaming
│   ├── AudioCaptureEngine.swift          # Mic capture (16kHz PCM)
│   ├── FnKeyMonitor.swift               # Fn key event tap
│   ├── GlobalShortcutMonitor.swift       # Shortcut event tap
│   ├── PermissionManager.swift           # macOS permissions
│   ├── SettingsStore.swift               # UserDefaults persistence
│   ├── ShortcutFormatter.swift           # Key display helpers
│   ├── SoundEffectPlayer.swift           # System sound playback
│   ├── TextInsertionService.swift        # AX insertion + paste fallback
│   ├── TranscriptStore.swift             # History persistence
│   └── UsageTracker.swift               # Local usage stats
└── UI/
    ├── DockTabController.swift           # Floating panel management
    ├── DockTabView.swift                 # Dock pill + bubbles
    ├── FloatingPanelController.swift
    ├── FloatingPanelView.swift
    ├── MainWindowController.swift
    ├── MainWindowView.swift              # Settings, transcripts, permissions
    ├── ShortcutRecorderSheet.swift
    └── WaveformView.swift

Resources/
├── Assets.xcassets/           # App icon + logo waveform
├── Blablabla.entitlements
└── Info.plist

project.yml                    # XcodeGen project definition
```

## Text insertion strategy

1. Tries **Accessibility API** direct text replacement on the focused UI element
2. Falls back to **clipboard + simulated Cmd+V** if AX fails
3. If no editable field is detected, saves to **transcript history**

## Known limitations

- Some secure or custom inputs reject both AX insertion and simulated paste
- The clipboard fallback temporarily replaces clipboard content (restores it after)
- For production distribution, token generation should move to a backend instead of using the API key directly

## License

MIT
