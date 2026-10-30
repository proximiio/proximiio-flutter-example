# Proximi.io Flutter example

An app that shows indoor positioning and the venue map, native and in a wayfinding web app, with the
Proximi.io Flutter SDK v6:
[`flutter_proximiio`](https://github.com/proximiio/flutter-proximiio) and
[`flutter_proximiio_map`](https://github.com/proximiio/flutter-proximiio-map), both at
`6.0.0-beta.6`.

## What it shows

**Position tab**

- The SDK state, with Start and Stop.
- The application and the visitor ID.
- The position: coordinate, accuracy, source and floor. A position without a floor, such as a GPS
  fix, is shown on the ground floor (level 0), and routes start there.
- The direction of walking from the last PDR step.
- The permissions the visitor granted.
- The geofences the visitor is inside.
- Recent events: floor changes, geofence and privacy-zone entries and exits.

**Places tab**

- The venue's points of interest that have a title, with a search field, as an app's own exhibitor
  list would show them.
- Tap a place for its details and **Take me there**: the app opens the Web tab, and the web app routes
  from the visitor's position to the place (see the Web tab).

**Map tab**

- The native Proximi.io map of the venue, with a floor selector.
- Tap a place to see its name. Tap **Route here** to show the route from your position, with
  turn-by-turn guidance.
- **Recentre**, **Whole venue** and **Clear route**.

**Web tab**

- A Proximi.io wayfinding web app (`PROXIMIIO_WAYFINDING_URL`) in a web view. It loads when the app
  starts and stays loaded, so it is ready when **Take me there** opens it.
- The app sends each SDK position to the web app as a message on `window`:

  ```js
  window.postMessage({"type": "SET_LOCATION", "latitude": 48.1486, "longitude": 17.1077, "level": 0}, "*");
  ```

  `level` is the floor level from the SDK, or 0 when the position has no floor. The web app ignores
  a message without `level`. The app sends the last position again every 3 seconds, because a phone
  standing still reports no new one.
- With each step the visitor takes, the app sends the direction of walking from PDR
  (`pdrObservations`), in degrees clockwise from north, and the web app turns the position marker:

  ```js
  window.postMessage({"type": "SET_HEADING", "heading": 87.5}, "*");
  ```

  A standing visitor takes no steps, so the marker keeps the last direction.
- **Take me there** sends the place's feature id, and the web app routes from the visitor's position to
  it at once:

  ```js
  window.postMessage({"type": "SET_DESTINATION", "id": "<feature id>", "start": "current"}, "*");
  ```

  The web app finds the place by its `id`, `title` or `remote_id`. For an app with its own list of
  exhibitors, `remote_id` set in the Portal to the exhibitor's id is the reliable key: titles can repeat.
- The web app answers on a JavaScript channel named `ProximiioHost` that the app adds to the web view:
  `{"type": "MAP_READY"}` once its map is loaded, then `{"type": "DESTINATION_SET", "id": …}` or
  `{"type": "DESTINATION_NOT_FOUND", "id": …}` for each destination. It keeps what arrives before its
  map is ready and handles it then. The app sends a destination once the web app said `MAP_READY`, and
  shows a message when the place is not found.

**Diagnostics tab**

For field tests. It refreshes every second while it is open.

- What the SDK reports about positioning: the source and age of the last position, its accuracy,
  why there is no position, the beacons in range against the venue's beacons, and whether PDR runs.
- The venue's beacons in range, strongest first: signal (dBm), transmit power and distance when known,
  and when each was last seen.
- **Copy** puts the diagnostics and the beacon list on the clipboard, to paste into a message.
- **Share report** shares the SDK's diagnostics report: a zip of everything recorded since the app
  started, without the token. The app starts the recording when it creates the SDK.

## Requirements

| Platform | Minimum |
| --- | --- |
| Flutter / Dart | Flutter 3.44, Dart 3.12 |
| iOS | iOS 15, Xcode 16 |
| Android | minSdk 26, compileSdk 37, JDK 17 |

You also need an application token from the Proximi.io Portal.

## Run

```bash
cp env.example.json env.json   # put your token in PROXIMIIO_TOKEN
flutter run --dart-define-from-file=env.json
```

`env.json` is git-ignored, so the token stays out of version control. Leave `PROXIMIIO_API_BASE_URL`
empty to use the default API. `PROXIMIIO_WAYFINDING_URL` is the web app of the Web tab, for example
`https://maps.proximi.io/<your-app>/`; use the token of the same application, so that both show
the same venue.

When it starts, the app asks for the permissions positioning needs. It then authenticates, loads the
route network and starts positioning. If you deny location access, allow it in the system settings
and tap **Start**.

**From an IDE.** In Android Studio or IntelliJ IDEA with the Flutter plugin, the shared run
configuration `main.dart` (in `.run/`) passes `--dart-define-from-file=env.json`. To run from Xcode,
first write the values into `ios/Flutter/Generated.xcconfig` (git-ignored):

```bash
flutter build ios --config-only --debug --dart-define-from-file=env.json
```

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
`didInitializeImplicitFlutterEngine`.

**Android.** The Android project is the one `flutter create` makes today (Gradle 9.3, Android Gradle
Plugin 9.1, Kotlin 2.4), so it builds on the JDK that Android Studio bundles. Only `compileSdk = 37` and
`minSdk = 26` differ from the template. The SDK's manifest adds the location, Bluetooth and network
permissions, so `AndroidManifest.xml` declares none.

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

The integration test starts the SDK against the live API, opens the map and the web app, and stops
positioning:

```bash
flutter test integration_test -d <device> --dart-define-from-file=env.json
```

The app asks for location when it starts; allow it within 60 seconds. `flutter test` reinstalls the
app, which drops an earlier grant. On the iOS Simulator you can grant it from a second terminal as
soon as the app is installed, before it asks:

```bash
until xcrun simctl get_app_container <device> io.proximi.flutterExample >/dev/null 2>&1; do sleep 0.2; done
xcrun simctl privacy <device> grant location io.proximi.flutterExample
```

## Code

| File | Contents |
| --- | --- |
| `lib/main.dart` | The app, the token from the build, the five tabs, **Take me there** |
| `lib/session.dart` | `SdkSession`: creates the SDK, starts the diagnostics recording, asks for permissions, authenticates, loads the route network, starts positioning and PDR, and keeps what the SDK streams report |
| `lib/status_tab.dart` | The Position tab |
| `lib/places_tab.dart` | The Places tab: the venue's places, their details, **Take me there** |
| `lib/map_tab.dart` | The Map tab: feature taps, routes, guidance |
| `lib/web_tab.dart` | `Wayfinding`, the web app in its web view: the positions, the direction and the destination sent to it; the Web tab |
| `lib/diagnostics_tab.dart` | The Diagnostics tab: the SDK's diagnostics, the beacons in range, the report to share |

The Map tab is built when you first open it and kept afterwards. The web app loads when the app starts.
