<div align="center">

# VocalFluid

**Free, 100% Local, Privacy-First AI Voice Dictation for macOS.**  
Hold a key, speak naturally, and beautifully formatted, cleaned-up text appears instantly at your cursor in any application.

A fast, completely on-device alternative to Wispr Flow. Zero cloud, zero accounts, zero subscriptions, zero data leaving your Mac.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)](https://github.com/joshuajaimon7/FlowLocal/releases)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%2F%20M2%20%2F%20M3%20%2F%20M4-black?logo=apple)](https://github.com/joshuajaimon7/FlowLocal/releases)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Download DMG](https://img.shields.io/badge/Download-VocalFluid.dmg-success?logo=apple&style=for-the-badge)](https://github.com/joshuajaimon7/FlowLocal/releases/latest/download/VocalFluid.dmg)

</div>

---

### [⬇️ Download Latest VocalFluid.dmg (Free)](https://github.com/joshuajaimon7/FlowLocal/releases/latest/download/VocalFluid.dmg)

---

## Overview

Voice dictation tools often send audio to cloud servers for transcription and processing. **VocalFluid runs the entire pipeline 100% locally on Apple Silicon:**

- **Speech-to-Text**: Accelerated on Apple Silicon Neural Engine (ANE) & GPU via [WhisperKit](https://github.com/argmaxinc/WhisperKit).
- **Intelligent Text Cleanup**: Real-time punctuation, grammar, and filler removal via local on-device models ([Ollama](https://ollama.com) / Qwen 2.5).
- **Highlight & Voice Transform**: Select any text on screen, hold Fn, and speak an instruction (*"Make this more concise"*, *"Translate to Spanish"*, *"Fix syntax"*) to rewrite it in place.
- **App-Context Awareness**: Automatically adapts formatting based on the active application (syntax and identifiers for VS Code/Terminal/Xcode; casual and emojis for Slack/WhatsApp; formal prose for Mail/Docs).

---

## Comparison

| Feature | Wispr Flow | VocalFluid |
| :--- | :--- | :--- |
| **Price** | Paid subscription ($12–$20/mo) | **100% Free & Open Source** |
| **Audio Privacy** | Cloud servers | **100% On-Device (Never leaves RAM)** |
| **Speech-to-Text Engine** | Cloud Whisper | **WhisperKit on Apple Neural Engine** |
| **AI Rewrite Engine** | Cloud LLM | **On-Device Local LLM (Ollama)** |
| **Highlight & Transform** | Limited | **Full In-Place Voice Rewriting** |
| **Floating Capsule** | Yes | **Adaptive Bottom-Center Capsule** |
| **App Context Awareness**| Basic | **Syntax-aware for Code, Chat & Docs** |
| **Supported Languages** | Multi | **13+ Languages with Direct Decoder Prior** |
| **Offline Operation** | Requires Internet | **Works 100% Offline anywhere** |

---

## Key Features

### 🎙️ Hardware-Accelerated Push-to-Talk
- **Hold `Fn` (🌐 Globe)** to speak; release to instantly clean and paste into the focused field.
- **Double-tap `Fn`** to lock hands-free recording for long dictation sessions.
- **Right `⌥ Option`** fallback for keyboards without an Fn key.

### 💊 Adaptive Floating Capsule Widget
- Renders as a subtle, unobtrusive capsule pill pinned right above the Dock.
- Dynamically expands when speaking to show live, smooth audio waves and real-time streaming transcript right inside the capsule.
- Smoothly displays status transitions (`Listening…` → `Pasting…` → minimal idle).

### ✍️ Highlight & Voice Transform
- Highlight text in any text field or editor.
- Hold **Fn** and speak an instruction:
  - *"Make this more polite"*
  - *"Convert this to Python snake_case"*
  - *"Summarize this in three bullet points"*
  - *"Translate to Spanish"*
- The highlighted text is instantly rewritten in place.

### 🧠 Target-App Intelligence
- **Code Editors (VS Code, Xcode, Cursor, Terminal)**: Formats programming terms (`camelCase`, `snake_case`), preserves code syntax, and keeps variable names intact.
- **Messaging (Slack, Messages, WhatsApp, Discord)**: Casual punctuation, optional emoji tone, and avoids awkward trailing periods.
- **Documents & Mail (Pages, Notes, Mail, Word)**: Formal grammar, clean paragraphs, and structured prose.

### 🌐 Multi-Language Support
Dedicated recognition for 13+ languages switchable in one click from the menu bar:
English, Spanish, French, German, Italian, Portuguese, Hindi, Japanese, Chinese, Russian, Arabic, Korean, and Auto-Detect.

### ⚡ Ultra-Lightweight & Battery Efficient
- Optimized to run in **under 500 MB total RAM** (~165 MB measured footprint).
- Dynamic 5-minute memory unloading to preserve battery life on MacBooks.

---

## Installation

### Option 1: Standalone DMG (Recommended)
1. Download **[VocalFluid.dmg](https://github.com/joshuajaimon7/FlowLocal/releases/latest/download/VocalFluid.dmg)**.
2. Open the disk image and drag **VocalFluid** into your **Applications** folder.
3. Launch VocalFluid. The built-in **3-Step Setup Wizard** will guide you through permissions and model configuration.

### Option 2: Build From Source
```bash
# Clone the repository
git clone https://github.com/joshuajaimon7/FlowLocal.git
cd FlowLocal

# Build the release app bundle
./scripts/make_app.sh

# Open the application
open build/VocalFluid.app
```

---

## Requirements

- **macOS 14 (Sonoma)** or later
- **Apple Silicon** (M1, M2, M3, M4 or newer)
- System Permissions: **Microphone** (speech capture) and **Accessibility** (global hotkey and text pasting)

---

## Acknowledgements

VocalFluid is built upon open-source research and engineering from:
- [FlowLocal](https://github.com/AlanRoybal/FlowLocal) by Alan Roybal (MIT License)
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax
- [Ollama](https://ollama.com) and the Qwen Team (Alibaba Cloud)

See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) for full licensing details.
