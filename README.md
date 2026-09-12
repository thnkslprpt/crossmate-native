# Crossmate Native

A from-scratch Flutter rewrite of Crossmate for Android and iOS. It does **not** use a WebView and it does not load the browser game at runtime. The board, rules engine, move validation, AI, history, themes, local play, and online-room client are written in Dart.

The gameplay baseline is the current browser release, **Crossmate v1.8.1**. See [docs/SOURCE_PARITY.md](docs/SOURCE_PARITY.md) for the preserved rules and the deliberate first-beta differences.
See [docs/VALIDATION.md](docs/VALIDATION.md) for the checks completed before packaging and the build checks that must run on a Flutter-equipped machine.

The reproducible toolchain target for this package is **Flutter 3.44.8 / Dart
3.12.2**.

## Included in this source package

- Native responsive Flutter interface for phones and tablets
- 7×7 and 9×9 Crossmate rules engine, matching browser v1.8.1
- All five piece types and their current movement rules
- Check, Crossmate (no legal move loses, even without check), cross capture, repetition, no-capture, and only-crosses endings
- Circle far-edge sacrifice choice
- Square and cross special diamond captures
- Three offline AI levels running outside the UI isolate
- Same-device two-player mode
- Firebase anonymous-auth online rooms with a 10-day expiry
- In-session move-history review in every mode
- First-launch rules onboarding and an always-available rules guide
- Four board themes
- Android/iOS app icon source and generation
- Engine/widget tests
- Ubuntu bootstrap, run, signing, Firebase, and release scripts
- GitHub Actions checks for Android and iOS

The bundle identifier/application ID is:

```text
com.gidigames.crossmate
```

The minimum iOS target is **iOS 15.0**, which includes iPhone 7. Android's minimum is **API 24 / Android 7.0**.
The eventual App Store archive must still be produced with the current submission-compatible Xcode/iOS SDK on macOS; the SDK used to build and the minimum deployment target are separate settings.

## 1. Unpack and enter the project

```bash
unzip crossmate-native-v0.1.0.zip
cd crossmate-native
chmod +x scripts/*.sh
```

## 2. Install Flutter on Ubuntu

The included helper installs the Flutter stable SDK and its Linux prerequisites:

```bash
./scripts/install_flutter_ubuntu.sh
```

Open a new terminal after it finishes. For the Android SDK and emulator, the easiest Ubuntu installation is Android Studio:

```bash
sudo snap install android-studio --classic
android-studio
```

In Android Studio's **SDK Manager**, install:

- The latest Android SDK Platform
- Android SDK Build-Tools
- Android SDK Command-line Tools
- Android SDK Platform-Tools
- One phone emulator image, if you are not using a real Android phone

Then accept the Android licenses:

```bash
flutter doctor --android-licenses
flutter doctor
```

Continue only when `flutter doctor` reports a working Flutter and Android toolchain. An iOS warning on Ubuntu is expected.

## Optional source-only check

Before Flutter is installed, Ubuntu can validate the packaged scripts and configuration files:

```bash
./scripts/verify_source.sh
```

This does not replace the real Flutter analyzer, tests, or platform builds.

## 3. Generate the native host project

The repository intentionally keeps the generated host projects reproducible. On Ubuntu, this command creates the Android host. On macOS, it creates any missing Android and iOS hosts. It also applies the Crossmate IDs and minimum OS versions, installs packages, generates icons, formats the Dart source, analyzes the project, and runs tests:

```bash
./scripts/bootstrap.sh
```

To regenerate the host projects later:

```bash
./scripts/bootstrap.sh --force
```

`--force` replaces the host projects supported on the current computer: Android on Ubuntu, and Android plus iOS on macOS. After using it, rerun the Firebase configuration script so the generated native Firebase files match your project again.

## 4. Run on Android

Enable USB debugging on a real Android phone and connect it, or start an emulator. Then:

```bash
./scripts/run_android.sh
```

Useful direct Flutter commands:

```bash
flutter devices
flutter run
```

```bash
flutter run --release
```

Local two-player and robot modes do not need Firebase and should work offline.

## 5. Configure online play with Firebase

The native app uses `crossmateNativeRooms`, while the browser game uses `crossmateRooms`. Their room data stays isolated, so both can safely use the same Firebase project. Realtime Database rules are deployed as one project-wide ruleset; for that reason `firebase/database.rules.json` deliberately preserves both nodes. Do not replace it with a native-only or browser-only rules file.

First install Node.js/npm if needed. Then run:

```bash
./scripts/configure_firebase.sh YOUR_FIREBASE_PROJECT_ID
```

The script installs Firebase CLI and FlutterFire CLI, logs in, configures every host project currently present, verifies that the rules file contains both Crossmate room nodes, and deploys the shared `firebase/database.rules.json`. On Ubuntu it configures Android. Run it again on the Mac after generating the iOS host so iOS is registered with the same `com.gidigames.crossmate` bundle identifier.

In Firebase Console, also enable:

```text
Authentication > Sign-in method > Anonymous
```

Create a Realtime Database if that Firebase project does not already have one.

After configuration, test online rooms using two app installations or an app plus a second emulator:

```bash
flutter run
```

Do not commit Firebase service-account files, signing keys, or passwords. The normal Firebase mobile configuration files identify the Firebase project but are not server administrator secrets; still review your repository visibility and database rules before publishing.

## 6. Back it up to GitHub

Create an empty GitHub repository, for example `crossmate-native`, then run from this project directory:

```bash
git init
git add .
git commit -m "Initial Crossmate native rewrite"
git branch -M main
git remote add origin git@github.com:YOUR_GITHUB_USERNAME/crossmate-native.git
git push -u origin main
```

If you use HTTPS rather than SSH:

```bash
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/crossmate-native.git
```

The `.gitignore` excludes Android signing properties, keystores, generated build output, and the local Firebase mobile configuration files. Those Firebase files are project identifiers rather than administrator credentials, but keeping them out of Git avoids automated secret-scanning noise. Re-run the Firebase configuration script on another development machine or transfer the two native config files privately.

## 7. Create a Play Store build

Create your permanent Google Play upload key once:

```bash
./scripts/configure_android_signing.sh
```

Back up the generated keystore and its passwords securely. Losing the upload credentials creates avoidable recovery work.

Build the signed Android App Bundle and a test APK:

```bash
./scripts/build_android.sh
```

Outputs:

```text
build/app/outputs/bundle/release/app-release.aab
build/app/outputs/flutter-apk/app-release.apk
```

Upload the `.aab` to an internal testing release in Google Play Console first.

## 8. Build the iPhone app

Most source development and all Android work can remain on Ubuntu. Apple compilation, signing, archiving, and App Store upload require macOS with Xcode, either on a physical Mac or a macOS build service.

On a Mac:

```bash
git clone git@github.com:YOUR_GITHUB_USERNAME/crossmate-native.git
cd crossmate-native
./scripts/bootstrap.sh
./scripts/configure_firebase.sh YOUR_FIREBASE_PROJECT_ID
./scripts/prepare_ios_on_mac.sh
```

The bootstrap generates the missing iOS host on macOS. The Firebase command then creates the ignored iOS configuration files. For an offline-only build, omit the Firebase command.

The script installs iOS pods, runs checks, performs an unsigned release compile, and opens:

```text
ios/Runner.xcworkspace
```

In Xcode:

1. Select the **Runner** target.
2. Set your Apple Developer Team under **Signing & Capabilities**.
3. Confirm the bundle identifier is `com.gidigames.crossmate`.
4. Test on a physical iPhone, including an iPhone 7 or iOS 15 device if available.
5. Choose **Product > Archive**.
6. Use Organizer to upload to App Store Connect.
7. Test through TestFlight before App Review.

See [docs/IOS_BUILD.md](docs/IOS_BUILD.md) for the longer checklist.

## 9. Development checks

Run these before every push:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build a release APK occasionally to catch native integration problems:

```bash
flutter build apk --release
```

## Important beta note

This package is a substantial first native implementation, not a store-approved binary. Before public release, complete real-device testing of every movement edge case, Firebase reconnects, app background/resume behavior, screen-reader labels, store privacy disclosures, icons/screenshots, and both stores' current review requirements.
