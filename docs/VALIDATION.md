# Package validation

## Browser v1.8.1 rules update — 2026-09-12

- Updated triangle movement, rotation, capture geometry and diamond captures, plus loss when no legal move exists even without check.
- Added 7×7 selection, state serialization, board rendering, robot support and online rematch size preservation.
- `flutter analyze --no-pub`: no issues found.
- `flutter build apk --debug --no-pub`: succeeded; APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter test --no-pub`: all 27 tests passed, including the new rules, both board sizes, flipped board taps, the size chooser and the 180° rotation control.
- Formatting checks pass for the game, services, screens, widgets and tests. A whole-project format check still flags pre-existing formatting in `lib/main.dart` and generated `lib/firebase_options.dart`.
- Live two-device online play and physical-device gameplay were not tested in this update.

The packaging checks below describe the original archive, before this update.

## Checks completed before packaging

- Compared the package baseline against the current `games/crossmate/index.html` source and confirmed browser version 1.7.3, the 9x9 formation, point values, four themes, 60-move draw rule, 10-day rooms, forcefield restriction, and square-backed triangle design.
- Ran `scripts/verify_source.sh` successfully after the final documentation and controller updates.
- Parsed every JSON and YAML configuration file.
- Verified every relative Dart import resolves to a packaged file.
- Scanned all Dart files for balanced delimiters and unfinished debug markers.
- Confirmed every shell script passes `bash -n`.
- Simulated `scripts/bootstrap.sh` on Linux and macOS with stub Flutter tools.
- Confirmed the Linux path creates Android only and the macOS path creates Android plus iOS.
- Confirmed Android API 24, portrait mode, Internet permission, iOS 15.0, display name, and orientation patches are applied.
- Confirmed a later bootstrap preserves FlutterFire's Android Google Services plugin.
- Confirmed platform-specific launcher-icon configuration and a 1024×1024 source icon.

## Checks not executable in the packaging environment

The packaging environment did not contain the Flutter/Dart SDK and could not download it, so it did not perform a real dependency resolution, Dart compile, `flutter analyze`, `flutter test`, Android Gradle build, iOS Xcode build, emulator run, or physical-device test.

`scripts/bootstrap.sh` performs package resolution, icon generation, Dart formatting, analysis, and tests on the developer machine. Treat the archive as a source beta until those commands pass and gameplay is tested on real devices.
