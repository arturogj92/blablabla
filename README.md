<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Blablabla">
</p>

<h1 align="center">Blablabla</h1>

<p align="center">
  <strong>Talk to your Mac. It types for you.</strong><br>
  Dictate anywhere — Slack, VS Code, ChatGPT, your terminal. No copy-paste, no window switching.<br>
  Just hold a key and speak.
</p>

<p align="center">
  <a href="https://www.assemblyai.com">Powered by AssemblyAI</a> · macOS 14+ · Open Source · MIT License
</p>

---

## Why Blablabla?

You think faster than you type. Every time you switch to a chat window, draft a prompt, or write an email, you're losing time. Blablabla turns your voice into text **directly where your cursor is** — no extra apps, no browser tabs, no friction.

**Send ChatGPT prompts with your voice.** Hold a key, describe what you need, release. The prompt appears in the text field ready to send. No typing, no editing, just talking.

**Reply to Slack in seconds.** Hold, speak your reply, release. Done. Next conversation.

**Write code comments, emails, docs** — anything that has a text cursor. Blablabla pastes the transcript right there.

---

## Key Features

**Instant dictation, zero UI**
Hold your shortcut and talk. Release to stop. The transcript appears where your cursor is. No windows to manage, no apps to switch to.

**Hands-free mode**
Double-tap the shortcut to lock recording. Keep talking as long as you need — write long emails, describe complex prompts, think out loud. Tap again to stop.

**Fn key push-to-talk**
Enable the Fn key as an alternative trigger. One key, no modifiers. The fastest way to start dictating.

**Works everywhere**
Slack, VS Code, Terminal, ChatGPT, Notion, Safari, Mail — if it has a text field, Blablabla can type into it. Uses macOS Accessibility APIs with a clipboard fallback.

**Multi-language, auto-detected**
Speak in English, Spanish, French, German, or any of 20+ languages. No configuration needed — the model detects your language automatically.

**Floating dock indicator**
A minimal waveform pill sits above your dock. It shows when you're recording, animates your audio level, and glows when locked. Follows your active screen on multi-monitor setups.

**Transcript history**
Every dictation is saved. Search through past transcripts, copy them, or clear them. Paginated for performance.

**Customizable sounds**
Pick from 13 macOS system sounds for start, lock, and stop events. Or turn them off entirely.

**Local usage tracking**
See how many sessions you've run and total dictation time. Check your AssemblyAI dashboard for exact billing with one click.

**Privacy-first**
Your API key stays on your machine. Audio streams directly to AssemblyAI — no middleman server, no data collection, no analytics. Fully open source so you can verify.

---

## Get Started

### Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Free [AssemblyAI](https://www.assemblyai.com) API key ($50 free credit on signup)

### Build from source

```bash
git clone https://github.com/arturogj92/blablabla.git
cd blablabla
xcodegen generate
```

**Run from Terminal:**

```bash
xcodebuild -project Blablabla.xcodeproj -scheme Blablabla -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Blablabla-*/Build/Products/Debug/Blablabla.app
```

**Or open in Xcode:**

```bash
open Blablabla.xcodeproj
# Cmd+R to build and run
```

### First launch

1. Paste your **AssemblyAI API key** in Settings
2. Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions
3. Restart the app
4. Hold your shortcut and start talking

---

## How It Works

| Action | What happens |
|--------|-------------|
| **Hold shortcut** | Push-to-talk — records while held, transcribes on release |
| **Double-tap shortcut** | Locks recording — keeps going until you tap again |
| **Hold Fn** *(optional)* | Same as push-to-talk, one key, no modifiers |
| **Click dock pill** | Toggle recording on/off |
| **Right-click dock pill** | Quick access to recent transcripts |

The default shortcut is `Option + Shift + §` (ISO Section key, next to Z on European keyboards). Fully customizable in Settings.

---

## Architecture

```
Sources/App/
├── AppDelegate.swift              # Lifecycle, shortcut & Fn monitors
├── AppModel.swift                 # Recording state machine
├── Services/
│   ├── AssemblyAIStreamingClient  # Real-time WebSocket streaming
│   ├── AudioCaptureEngine         # 16kHz mono PCM capture
│   ├── GlobalShortcutMonitor      # CGEvent tap for shortcuts
│   ├── FnKeyMonitor               # Fn key event monitoring
│   ├── TextInsertionService       # AX insertion + paste fallback
│   ├── SoundEffectPlayer          # AudioToolbox system sounds
│   └── ...
└── UI/
    ├── DockTabView                # Floating waveform pill
    ├── MainWindowView             # Settings, history, permissions
    └── ...
```

Built with Swift, AppKit, and SwiftUI. No Electron. No web views. Native macOS from top to bottom.

---

## Contributing

Contributions are welcome! Some ideas:

- **AI post-processing** — clean up transcripts with an LLM before pasting
- **Voice commands** — "delete that", "new paragraph", "undo"
- **Output templates** — format as bullet points, email, code comment
- **Auto-launch at login**
- **Whisper fallback** — offline transcription when there's no internet

---

## License

MIT — use it, fork it, ship it.
