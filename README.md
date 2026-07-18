# GameLingo

GameLingo is a native macOS menu bar app that captures text from games and translates it into the language you choose.

Screen capture, text recognition, and translation all run locally using Apple's ScreenCaptureKit, Vision, and Translation frameworks. No screenshots or recognized text are sent to a third-party service.

## Features

- Configurable source and target languages based on the languages supported by Apple on your Mac.
- Region capture with a customizable global shortcut (`⌥⌘T` by default).
- Persistent **Repeat Last Region** shortcut (`⌥⌘R`).
- Experimental **Live Subtitles** mode (`⌥⌘S`) with dialogue-change detection.
- Floating translation card that works over full-screen apps and Spaces.
- Optional original text and a one-click copy action.
- Multi-display region selection.

## How to use

1. Open `GameLingo.app`. A translation icon appears in the menu bar.
2. Open **Settings** and choose the source and target languages.
3. Press `⌥⌘T` from any app.
4. Drag over the text you want to translate.
5. GameLingo shows the translation in a floating card. Press `Esc` to close it.

You can change the main shortcut in **Settings**.

### Live Subtitles (experimental)

1. Press `⌥⌘S` and select the game's dialogue box.
2. GameLingo checks that region periodically and translates only when the dialogue changes.
3. Press `⌥⌘S` again to stop live mode.

GameLingo excludes its own windows from continuous capture so the translation card is not read back by OCR. A live subtitle region must fit entirely within one display.

## Language support

GameLingo loads the language list directly from Apple Translation on each Mac and uses a built-in fallback list if the system service is temporarily unavailable. Source languages are further limited to those that Apple Vision can recognize with OCR. The first translation for a new pair may ask macOS to download the required language models.

The default language pair is English to Spanish. Both languages are persistent and configurable in **Settings**.

## Requirements

- macOS 15.2 or later.
- Screen Recording permission for GameLingo.
- Swift 6 and Xcode Command Line Tools to build from source. Full Xcode is not required.

## Build from source

```bash
chmod +x Scripts/build-app.sh Scripts/test.sh
./Scripts/test.sh
./Scripts/build-app.sh
open dist/GameLingo.app
```

The build script creates `dist/GameLingo.app` and applies a local ad hoc signature. Public distribution outside GitHub source builds requires an Apple Developer ID signature and notarization.

## Screen Recording permission

macOS requests screen capture access on first use. If the prompt does not appear or permission was denied:

1. Open **System Settings**.
2. Go to **Privacy & Security → Screen & System Audio Recording**.
3. Enable GameLingo.
4. Quit and reopen the app if macOS asks you to.

Some games use exclusive capture or protection mechanisms that prevent macOS from providing an image. Borderless windowed mode is usually the most compatible option.

## Project status

GameLingo is an early-stage project. Live subtitles are experimental, and the app is currently distributed as a source build.
