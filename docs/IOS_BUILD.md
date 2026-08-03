# iOS build and App Store checklist

## What Ubuntu can do

Ubuntu can edit all Dart code, generate and build the Android project, run engine/widget tests, configure Android online play, and push the repository to GitHub. The iOS host project is generated later on macOS by the same bootstrap script.

## What requires macOS

Apple's iOS SDK and Xcode toolchain run on macOS. A signed `.ipa`, device provisioning, archive validation, and App Store Connect upload therefore need a Mac or a hosted macOS CI/build machine.

## Mac preparation

1. Install the current App Store submission-compatible Xcode. As of the 2026 release cycle, App Store uploads must be built with the iOS 26 SDK or later; this does not change the app's iOS 15.0 deployment target.
2. Install the Flutter stable SDK.
3. Install CocoaPods.
4. Sign in to Xcode with the Apple ID enrolled in the Apple Developer Program.
5. Clone this repository.
6. Run:

```bash
./scripts/prepare_ios_on_mac.sh
```

## Xcode setup

Open `ios/Runner.xcworkspace`, not `Runner.xcodeproj`.

Under Runner > Signing & Capabilities:

- Select your Team.
- Use bundle ID `com.gidigames.crossmate` or change it consistently if that ID is unavailable.
- Enable automatic signing for the first build.
- Add any later capabilities such as Associated Domains, Game Center, or Push Notifications only when implemented.

The deployment target is iOS 15.0. Keep it there to support iPhone 7.

## Firebase

Confirm `ios/Runner/GoogleService-Info.plist` exists after FlutterFire configuration. Never use a server service-account JSON file in the app.

## Device tests

Test at minimum:

- iPhone 7-sized display and iOS 15 behavior
- a current notched/Dynamic Island iPhone
- portrait and upside-down portrait
- backgrounding during AI search and online turns
- network loss/reconnect
- audio interruption if sound is later added
- VoiceOver focus and semantic board labels
- online room creation and joining on two devices
- fresh install, upgrade, uninstall/reinstall

## TestFlight and release

1. Increment `version:` in `pubspec.yaml` as `major.minor.patch+build`.
2. Run `flutter test` and a release compile.
3. Product > Archive in Xcode.
4. Validate and upload in Organizer.
5. Create an internal TestFlight group.
6. Complete App Privacy, age rating, support URL, screenshots, review notes, and export-compliance questions in App Store Connect.
7. Submit only after TestFlight testing is stable.
