# AMI AI

AMI (AI Multimodal Intelligence) is a screen-aware voice companion for Android.
Talk to it, share your screen, and get short, human answers powered by Google
Gemini, Groq, or Cloudflare Workers AI.

[![Build Android APK](https://github.com/evereasygaming-ux/AMI-AI/actions/workflows/build-apk.yml/badge.svg)](https://github.com/evereasygaming-ux/AMI-AI/actions/workflows/build-apk.yml)

## Features

- Voice conversations with speech-to-text input and spoken replies.
- Natural voice: automatically picks the best available neural/network voice
  from Google Text-to-Speech for the selected language.
- Floating 3D robot: a tiny animated robot overlays other apps. Tap it to read
  the current screen aloud without leaving the app you are in.
- Optional Android accessibility foundation: after an in-app disclosure and
  explicit opt-in, AMI exposes active-screen UI nodes plus tap and text-entry
  methods through its Dart/Kotlin bridge. This phase keeps the node tree on the
  phone and does not connect it to either AI provider.
- Screen awareness: share your screen so AMI can read what is visible and answer
  questions about "this" or "my screen".
- Quick delayed screen look with a countdown before capturing.
- Chat history with a dedicated chat screen.
- Select Gemini (default), Groq, or Cloudflare Workers AI from Settings, with
  separate credentials and model settings for each provider.
- API keys are stored locally with `shared_preferences`; requests and attached
  screen images go only to the selected provider.
- Dark, glass-style UI with an animated voice orb.
- GitHub Actions runs Dart analysis and Flutter tests before building the
  release APK.

## Supported models

| Model | Model ID | Notes |
| --- | --- | --- |
| Gemini 3.5 Flash Lite | `gemini-3.5-flash-lite` | Fastest and lightest |
| Gemini 3.6 Flash | `gemini-3.6-flash` | Default; best speed/quality balance |
| Gemini 3.1 Pro | `gemini-3.1-pro` | Strongest reasoning |
| Groq Qwen 3.8 27B | `qwen/qwen3.8-27b` | Text and image input |
| Cloudflare Gemma 4 26B A4B | `@cf/google/gemma-4-26b-a4b-it` | Text and image input |

You can also type a different model ID manually in Settings.

## Tech stack

- Flutter 3.47.7 / Dart 3.13.5
- Google Gemini API (`generativelanguage.googleapis.com`, `v1beta`)
- Groq Chat Completions API (`api.groq.com/openai/v1`)
- Cloudflare Workers AI Chat Completions API
- `speech_to_text` for voice input
- `flutter_tts` for spoken replies
- `http` for Gemini, Groq, and Cloudflare requests
- `shared_preferences` for local settings
- Kotlin Android `MediaProjection` service for screen capture
- Kotlin Android Accessibility Service with a user-consent disclosure and
  Flutter method-channel bridge

## Requirements

- Flutter 3.47.7 or newer with Dart 3.13.5
- JDK 17
- Android SDK (compile/target SDK provided by Flutter)
- A Gemini key from [Google AI Studio](https://aistudio.google.com/apikey) or
  a Groq key from [Groq Console](https://console.groq.com/keys), or a
  Cloudflare Account ID and Workers AI API token
- An Android device or emulator (screen capture is Android-only)

## Getting started

```bash
git clone https://github.com/evereasygaming-ux/AMI-AI.git
cd AMI-AI
flutter pub get
flutter run
```

Then open **Settings**, select a provider, enter its credentials, choose its
model, and start talking. Cloudflare requires both an Account ID and Workers AI
API token. Screen sharing and microphone permissions are requested by Android
at runtime.

### Floating robot

In **Settings > FLOATING ROBOT**, turn on **Floating robot**. Android will ask
for the **Display over other apps** permission. Once granted, turn the switch on
again if needed. The robot then floats above any app:

- Drag the robot to move it anywhere on screen.
- Tap the robot to capture the current screen, ask the selected provider what is on it, and
  hear the answer aloud.
- Screen reading requires screen context to be on. If it is off, tapping the
  robot opens AMI so you can enable it.
- Use the notification's **Stop** action or turn the switch off to remove it.

## Building the APK

### GitHub Actions (recommended)

The workflow at `.github/workflows/build-apk.yml` runs on every push to `main`
or `master`, on pull requests, and manually via **Actions > Build Android APK >
Run workflow**.

It:

1. Sets up JDK 17 and Flutter 3.47.7.
2. Runs `flutter pub get`.
3. Runs `flutter build apk --release`.
4. Uploads `app-release.apk` as the `ami-ai-release-apk` artifact.

Download the APK from the workflow run's **Artifacts** section.

### Local build

```bash
flutter pub get
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

### Building on Termux

Termux ships an ARM `aapt2`, while AGP expects an x86_64 build. Keep the override
in your local Gradle home instead of the project:

```bash
echo 'android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2' \
  >> ~/.gradle/gradle.properties
```

Also make sure `android/gradlew` uses a portable shebang
(`#!/usr/bin/env bash`) and is executable.

## Project structure

```text
lib/
  main.dart                     App entry point and tab shell
  ami_controller.dart           App state, voice/screen flow, provider routing
  app_theme.dart                Colors, gradients, glass panels
  models/chat_message.dart      Chat message model
  screens/                      Home, chat, and settings screens
  services/
    gemini_service.dart         Gemini API client and error handling
    groq_service.dart           Groq API client and error handling
    cloudflare_service.dart     Cloudflare Workers AI client and error handling
    overlay_service.dart        Floating robot bridge
    accessibility_bridge.dart   Accessibility Service bridge
    settings_service.dart       Local settings persistence
    screen_capture_service.dart Android screen capture bridge
    voice_service.dart          Speech-to-text, neural voice selection, TTS
  widgets/voice_orb.dart        Animated voice orb
android/
  app/src/main/kotlin/...       MainActivity, ScreenCaptureService,
                                FloatingOrbService, RobotOrbView,
                                AmiAccessibilityService
  app/build.gradle.kts          Android app configuration
```

## Permissions

| Permission | Why it is needed |
| --- | --- |
| `INTERNET` | Send requests to the selected AI provider |
| `RECORD_AUDIO` | Voice input |
| `FOREGROUND_SERVICE` | Keep screen capture running |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Android 14+ screen capture service |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Keep the floating robot service alive |
| `POST_NOTIFICATIONS` | Show screen-sharing and floating robot notifications |
| `SYSTEM_ALERT_WINDOW` | Draw the floating robot over other apps |
| Android Accessibility Service | Optional user-enabled access to visible UI labels and controls; password text is redacted and text entry into password fields is blocked |

## Privacy

- Both provider API keys are stored only on the device.
- Chat history is kept in memory for the current session.
- Screenshots are captured only while screen sharing is active and are sent only
  to whichever provider is selected as part of your request.
- The optional accessibility bridge returns a bounded UI-node list to AMI on the
  phone. Password-field text and descriptions are redacted; text entry into
  password fields is blocked. The node list is not sent to either provider.
- The floating robot does not read the screen on its own. A capture happens only
  when you tap it while screen context is on.
- No analytics, tracking, or third-party servers are used by this app.

## Release signing

The current `release` build type uses the Android debug signing key so that
release builds are installable out of the box. For Play Store distribution,
create a keystore, configure `key.properties`, and update
`android/app/build.gradle.kts` to use your release signing config.

## Contributing

Issues and pull requests are welcome. Please run the following before opening a
PR:

```bash
flutter analyze
flutter test
```

## License

Released under the [MIT License](LICENSE).

## Disclaimer

This project is not affiliated with or endorsed by Google. Gemini is a trademark
of Google LLC. Use of the Gemini API is subject to Google's terms and pricing.
