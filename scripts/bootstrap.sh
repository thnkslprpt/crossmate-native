#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[crossmate] ERROR: Flutter is not on PATH. Run scripts/install_flutter_ubuntu.sh first." >&2
  exit 1
fi

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

PLATFORMS=(android)
if [[ "$(uname -s)" == "Darwin" ]]; then
  PLATFORMS+=(ios)
fi

if [[ $FORCE -eq 1 ]]; then
  for platform in "${PLATFORMS[@]}"; do
    rm -rf "$platform"
  done
fi

MISSING=()
for platform in "${PLATFORMS[@]}"; do
  if [[ ! -d "$platform" ]]; then
    MISSING+=("$platform")
  fi
done

if [[ ${#MISSING[@]} -gt 0 || ! -f .metadata ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  TEMPLATE_PLATFORMS=("${MISSING[@]}")
  if [[ ${#TEMPLATE_PLATFORMS[@]} -eq 0 ]]; then
    TEMPLATE_PLATFORMS=("${PLATFORMS[0]}")
  fi
  PLATFORM_CSV="$(IFS=,; echo "${TEMPLATE_PLATFORMS[*]}")"
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "[crossmate] Generating native host project(s): $(IFS=,; echo "${MISSING[*]}")"
  else
    echo "[crossmate] Restoring Flutter project metadata"
  fi
  flutter create \
    --platforms="$PLATFORM_CSV" \
    --org com.gidigames \
    --project-name crossmate \
    "$TMP/crossmate"
  if [[ -f "$TMP/crossmate/.metadata" ]]; then
    cp "$TMP/crossmate/.metadata" .metadata
  fi
  for platform in "${MISSING[@]}"; do
    cp -a "$TMP/crossmate/$platform" "$platform"
  done
fi

python3 - <<'PY'
from pathlib import Path
import plistlib
import re

root = Path.cwd()

# Android Gradle 9 compatibility for Flutter 3.44.x.
gradle_properties = root / 'android/gradle.properties'
if gradle_properties.exists():
    properties_text = gradle_properties.read_text()
    property_lines = properties_text.splitlines()
    required_properties = {
        'android.newDsl': 'false',
        'android.builtInKotlin': 'false',
    }
    for property_name, property_value in required_properties.items():
        replacement = f'{property_name}={property_value}'
        matching_indexes = [
            index for index, line in enumerate(property_lines)
            if line.strip().startswith(f'{property_name}=')
        ]
        if matching_indexes:
            property_lines[matching_indexes[0]] = replacement
            for duplicate_index in reversed(matching_indexes[1:]):
                del property_lines[duplicate_index]
        else:
            property_lines.append(replacement)
    gradle_properties.write_text('\n'.join(property_lines).rstrip() + '\n')

# Android: minimum Android 7/API 24, portrait, and release signing support.
gradle = root / 'android/app/build.gradle.kts'
if gradle.exists():
    existing_gradle = gradle.read_text()
    google_services_plugin = (
        '    id("com.google.gms.google-services")\n'
        if 'com.google.gms.google-services' in existing_gradle
        else ''
    )
    gradle.write_text('''import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
''' + google_services_plugin + '''}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gidigames.crossmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.gidigames.crossmate"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
''')
else:
    legacy = root / 'android/app/build.gradle'
    if legacy.exists():
        text = legacy.read_text()
        text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', text)
        legacy.write_text(text)

manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    text = manifest.read_text()
    if 'android.permission.INTERNET' not in text:
        text = text.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.INTERNET" />',
            1,
        )
    text = text.replace('android:label="crossmate"', 'android:label="Crossmate"')
    if 'android:screenOrientation=' not in text:
        text = text.replace(
            'android:exported="true"',
            'android:exported="true"\n            android:screenOrientation="portrait"',
            1,
        )
    manifest.write_text(text)

# iOS: deployment target 15.0 and portrait-only phone UI.
podfile = root / 'ios/Podfile'
if podfile.exists():
    text = podfile.read_text()
    platform_pattern = r"(?m)^\s*#?\s*platform :ios,\s*'[^']+'\s*$"
    if re.search(platform_pattern, text):
        text = re.sub(platform_pattern, "platform :ios, '15.0'", text, count=1)
    else:
        text = "platform :ios, '15.0'\n" + text
    podfile.write_text(text)

pbx = root / 'ios/Runner.xcodeproj/project.pbxproj'
if pbx.exists():
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;',
                  'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', pbx.read_text())
    pbx.write_text(text)

plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    with plist.open('rb') as handle:
        data = plistlib.load(handle)
    data['CFBundleDisplayName'] = 'Crossmate'
    data['UISupportedInterfaceOrientations'] = [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
    ]
    data['UISupportedInterfaceOrientations~ipad'] = [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
    ]
    with plist.open('wb') as handle:
        plistlib.dump(data, handle, sort_keys=False)
PY

if [[ -d android ]]; then
  cat > android/key.properties.example <<'KEYEOF'
storePassword=CHANGE_ME
keyPassword=CHANGE_ME
keyAlias=upload
storeFile=/absolute/path/to/crossmate-upload-keystore.jks
KEYEOF
fi

echo "[crossmate] Resolving packages"
flutter pub get

echo "[crossmate] Generating app icons for available host projects"
if [[ -d android ]]; then
  dart run flutter_launcher_icons -f flutter_launcher_icons_android.yaml
fi
if [[ -d ios ]]; then
  dart run flutter_launcher_icons -f flutter_launcher_icons_ios.yaml
fi

echo "[crossmate] Formatting Dart source"
dart format lib test

echo "[crossmate] Running analyzer and tests"
flutter analyze
flutter test

echo "[crossmate] Native host projects are ready for this computer."
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[crossmate] Android and iOS hosts are available."
else
  echo "[crossmate] Android is available. The iOS host will be generated on macOS."
  echo "[crossmate] Run: ./scripts/run_android.sh"
fi
