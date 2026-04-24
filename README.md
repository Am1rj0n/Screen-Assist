# ScreenAssist

A privacy-first floating glass dashboard for macOS that captures your screen on demand,
reads it with OCR, and returns a concise AI answer.

Supports **OpenAI (ChatGPT)**, **Anthropic Claude**, and **Google Gemini**.

---

## What it looks like

- A thin **58pt glass bar** that floats over all windows, draggable anywhere
- Click the chevron or press **⌘⇧Space** to expand the full panel
- Adjustable opacity slider built into the bar
- Black / glass aesthetic — no dock icon, no clutter

---

## Requirements

| Item | Requirement |
|------|-------------|
| macOS | 15.0 Sequoia or later |
| Xcode | 15 or later (free from App Store) |
| API key | At least one from OpenAI / Claude / Gemini |

---

## Step-by-Step Build Instructions

### Step 1 — Install Xcode (if you haven't)

Open the **Mac App Store**, search **Xcode**, install it (it's free, ~7 GB).
After install, open it once and accept the license agreement.

---

### Step 2 — Open the project

1. Unzip **ScreenAssist.zip** anywhere (e.g. your Desktop)
2. Double-click **ScreenAssist.xcodeproj**
   Xcode will open automatically.

---

### Step 3 — Set your signing team

You need a free Apple ID to sign the app — no paid developer account required.

1. In Xcode, click **ScreenAssist** in the left sidebar (the blue icon at the very top)
2. Click the **ScreenAssist** target in the middle column
3. Click the **Signing & Capabilities** tab
4. Under **Team**, click the dropdown and choose your Apple ID
   (If it's not there: Xcode → Settings → Accounts → click + → add your Apple ID)
5. The "Signing Certificate" error will clear automatically

---

### Step 4 — Build and Run

Press **⌘ + R** (or click the ▶ Play button at the top).

Xcode will compile the app and launch it. You'll see a **viewfinder icon** appear
in your menu bar at the top right of your screen. That's it — the app is running.

---

### Step 5 — Grant Permissions (one-time)

**Screen Recording** (required):
```
System Settings → Privacy & Security → Screen Recording
→ Toggle ON next to ScreenAssist
```

**Accessibility** (required for global hotkeys ⌘⇧Space / ⌘⇧C):
```
System Settings → Privacy & Security → Accessibility
→ Click + → navigate to ScreenAssist → Add it → Toggle ON
```

After granting Screen Recording, you may need to quit and relaunch the app once.

---

### Step 6 — Add your API key

1. Click the **viewfinder icon** in the menu bar
2. Click the **∨ chevron** to expand the panel
3. Click **ChatGPT**, **Claude**, or **Gemini** to select your provider
4. Paste your API key in the key field
5. Click **Save** — it's stored in macOS Keychain, never on disk

---

### Step 7 — Use it

| Action | How |
|--------|-----|
| Show / Hide panel | **⌘⇧Space** or click the menu bar icon |
| Capture + analyze | Click the **⊙** camera button, or press **⌘⇧C** |
| Expand panel | Click the **∨** chevron |
| Ask a question | Type in the prompt field, then capture |
| Copy response | Click **Copy** in the response section |
| Adjust opacity | Drag the small slider in the top bar |
| Move the panel | Click and drag anywhere on it |
| Quit | Menu bar icon → right-click → Quit |

---

## Make it launch at login (optional)

1. Open **System Settings → General → Login Items**
2. Click **+** and add ScreenAssist.app

To find the built app:
- In Xcode: **Product → Show Build Folder in Finder**
- Navigate to `Products/Release/ScreenAssist.app`
- Or just drag it from `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/`

---

## Share with others

To give the app to someone else on a Mac:

1. In Xcode: **Product → Archive** (make sure scheme is set to "My Mac")
2. Xcode Organizer opens → click **Distribute App**
3. Choose **Direct Distribution** → **Export**
4. Send them the exported `.app` file (zip it first)

They just drag it to `/Applications` and double-click.
First launch: right-click → Open (to bypass the unsigned developer warning).

---

## API Keys — Where to Get Them

| Provider | Key format | Free tier? | Link |
|----------|-----------|-----------|------|
| OpenAI (ChatGPT) | `sk-proj-...` | No (pay-as-you-go, very cheap) | https://platform.openai.com/api-keys |
| Anthropic (Claude) | `sk-ant-...` | No (pay-as-you-go) | https://console.anthropic.com |
| Google (Gemini) | `AIza...` | **Yes — free tier available** | https://aistudio.google.com/app/apikey |

**Cheapest option**: Gemini 1.5 Flash is free up to 15 requests/minute.
**Fastest option**: GPT-4o-mini or Claude Haiku — fractions of a cent per capture.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘ ⇧ Space | Show / Hide the floating panel |
| ⌘ ⇧ C | Capture screen now |

---

## Privacy & Security

| Concern | How it's handled |
|---------|----------------|
| API keys | Stored in macOS Keychain only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| Screenshots | Processed in RAM — never saved to disk |
| Background capture | Impossible — no timers, no observers, no recording |
| Network | Only calls the AI provider you selected |
| Telemetry | None whatsoever |

---

## Troubleshooting

**App doesn't appear after ⌘R**
→ Check Xcode's build output at the bottom for errors.
→ Make sure your signing team is set (Step 3).

**"Screen capture failed" error**
→ System Settings → Privacy & Security → Screen Recording → enable ScreenAssist.
→ Quit and relaunch after granting permission.

**Hotkeys not working**
→ System Settings → Privacy & Security → Accessibility → add and enable ScreenAssist.

**"Unidentified developer" warning when opening the app**
→ Right-click the .app → Open → Open (first time only, bypasses Gatekeeper).

**API error / wrong key**
→ Make sure you selected the right provider (ChatGPT / Claude / Gemini) before saving the key.
→ Claude keys start with `sk-ant-`, OpenAI with `sk-` or `sk-proj-`, Gemini with `AIza`.

**Panel disappeared**
→ Press ⌘⇧Space to bring it back, or click the viewfinder icon in the menu bar.

---

## File Structure (for developers)

```
ScreenAssist/
├── App/
│   ├── ScreenAssistApp.swift        — Entry point (@main)
│   ├── AppDelegate.swift            — Panel, status bar, hotkeys
│   ├── FloatingDashboardView.swift  — Glass UI, all interactions
│   └── SettingsView.swift           — ⌘, preferences window
├── Core/
│   ├── ScreenCapturer.swift         — ScreenCaptureKit + CGWindow fallback
│   ├── OCRProcessor.swift           — Apple Vision OCR (in-memory)
│   └── AIClient.swift               — OpenAI / Claude / Gemini unified client
├── Utils/
│   ├── KeychainHelper.swift         — Secure key storage
│   └── HotkeyManager.swift          — Carbon global hotkeys
├── Assets.xcassets/                 — App icon + accent color
├── Info.plist                       — Hides dock icon, permissions
└── ScreenAssist.entitlements        — Network + no-sandbox config
```

---

## Command Line Interface (TerminalAssist Tool)

We've added a new CLI version of the tool (codenamed `TA`) that allows you to trigger captures and set keys directly from your terminal.

### Installation

Run the secure installer script from the root of the project:

```bash
./scripts/install.sh --tool TA
```

The script will safely compile the CLI and install it to `/usr/local/bin` (or a local `.bin` folder if permissions are restricted).

### Usage

```bash
TA capture         # Capture screen and run AI analysis
TA key set <key>   # Set your API key securely
```

