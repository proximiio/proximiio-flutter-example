# Proximi.io Flutter example

An app that shows indoor positioning and the venue map with the Proximi.io Flutter SDK v6:
[`flutter_proximiio`](https://github.com/proximiio/flutter-proximiio) and
[`flutter_proximiio_map`](https://github.com/proximiio/flutter-proximiio-map), both at
`6.0.0-beta.1`.

## What it shows

**Position tab**

- The SDK state, with Start and Stop.
- The application and the visitor ID.
- The position: coordinate, accuracy, source and floor. A position without a floor, such as a GPS
  fix, is shown on the ground floor (level 0), and routes start there.
- The permissions the visitor granted.
- The geofences the visitor is inside.
- Recent events: floor changes, geofence and privacy-zone entries and exits.

**Map tab**

- The native Proximi.io map of the venue, with a floor selector.
- Tap a place to see its name. Tap **Route here** to show the route from your position, with
  turn-by-turn guidance.
- **Recentre**, **Whole venue** and **Clear route**.

## Requirements

| Platform | Minimum |
| --- | --- |
| Flutter / Dart | Flutter 3.38, Dart 3.10 |
| iOS | iOS 15, Xcode 16 |
| Android | minSdk 26, compileSdk 37, Android Gradle Plugin 8.13, Gradle 8.13, Kotlin 2.2, JDK 17 |

You also need an application token from the Proximi.io Portal.

## Run

```bash
cp env.example.json env.json   # put your token in PROXIMIIO_TOKEN
flutter run --dart-define-from-file=env.json
```

`env.json` is git-ignored, so the token stays out of version control. Leave `PROXIMIIO_API_BASE_URL`
empty to use the default API.

When it starts, the app asks for the permissions positioning needs. It then authenticates, loads the
route network and starts positioning. If you deny location access, allow it in the system settings
and tap **Start**.

## Platform notes

**iOS.** The map library ships only as a Swift package. `pubspec.yaml` turns on Flutter's Swift
Package Manager support for this project, so the app needs no CocoaPods:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

`ios/Runner/Info.plist` has the six usage descriptions the SDK requires. App Store validation
rejects an upload without them.

The app uses the UIScene lifecycle, which iOS 27 requires: `Info.plist` declares the scene manifest
with `FlutterSceneDelegate`, and `AppDelegate` registers the plugins in
`didInitializeImplicitFlutterEngine`. This needs Flutter 3.38 or newer.

**Android.** The SDK's manifest adds the location, Bluetooth and network permissions, so
`AndroidManifest.xml` declares none. The project's Gradle 8.14 runs on JDK 17 to 24. If
`flutter build apk` fails with a Java version error, for example on the JDK 25 that recent Android
Studio versions bundle, point Flutter at JDK 17:

```bash
flutter config --jdk-dir <path to JDK 17>
```

## Simulators and emulators

Simulators and emulators have no Bluetooth, so the position comes from the simulated location:

- iOS Simulator: **Features › Location › Custom Location**.
- Android Emulator: **Extended controls › Location**.

The map draws the position from the first fix after the map opens. A fixed simulated location sends
no further fix on iOS, so use a moving one there:

```bash
xcrun simctl location <device> start --speed=1.4 <lat>,<lng> <lat>,<lng> …
```

## Tests

```bash
flutter test   # widget test, no SDK needed
```

The integration test starts the SDK against the live API, opens the map and stops positioning:

```bash
flutter test integration_test -d <device> --dart-define-from-file=env.json
```

The app asks for location when it starts; allow it within 60 seconds. `flutter test` reinstalls the
app, which drops an earlier grant. On the iOS Simulator you can grant it from a second terminal as
soon as the app is installed, before it asks:

```bash
until xcrun simctl get_app_container <device> com.example.proximiioFlutterExample >/dev/null 2>&1; do sleep 0.2; done
xcrun simctl privacy <device> grant location com.example.proximiioFlutterExample
```

## Code

| File | Contents |
| --- | --- |
| `lib/main.dart` | The app, the token from the build, the two tabs |
| `lib/session.dart` | `SdkSession`: creates the SDK, asks for permissions, authenticates, loads the route network, starts positioning, and keeps what the SDK streams report |
| `lib/status_tab.dart` | The Position tab |
| `lib/map_tab.dart` | The Map tab: feature taps, routes, guidance |

The map tab is built when you first open it and is kept afterwards, with its camera and route.
