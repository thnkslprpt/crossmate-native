# Package validation

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
