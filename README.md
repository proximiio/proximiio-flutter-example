# Proximiio Flutter Example

A comprehensive example application demonstrating how to use the `flutter_proximiio` and `flutter_proximiio_map` plugins for indoor positioning and mapping.

## Overview

This example app showcases:

- **Real-time Location Tracking**: Display GPS coordinates and indoor positioning data
- **Interactive Map View**: Visualize your location on a Proximiio map with WebView integration
- **Floor Detection**: Automatic floor level detection in multi-story buildings
- **Geofence Monitoring**: Track when users enter and exit geofenced areas
- **Data Visualization**: Clean UI showing all location data in an organized manner

## Features

The app includes two main tabs:

### Data Tab
- Displays current connection status
- Shows visitor ID
- Real-time GPS coordinates (latitude, longitude, accuracy, source)
- Current floor information
- Active geofences
- Permission request handling

### Map Tab
- Interactive Proximiio map powered by WebView
- Real-time position updates
- Feature click handling
- Map controls (zoom, pan, rotate)

## Setup

### 1. Get Your Proximiio Token

Replace the token in `lib/main.dart` with your actual Proximiio API token:

```dart
const String token = 'your-proximiio-token-here';
```

You can get your token from the [Proximiio Portal](https://portal.proximi.io).

### 2. iOS Setup

Add location and Bluetooth permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect beacons for indoor positioning</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to detect beacons for indoor positioning</string>
```

Run pod install:

```bash
cd ios && pod install
```

### 3. Android Setup

Permissions are already configured in `android/app/src/main/AndroidManifest.xml`.

## Running the App

1. Install dependencies:

```bash
flutter pub get
```

2. Run on your device or simulator:

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

3. Grant location permissions when prompted

## Testing

### On Physical Device

For best results, test on a physical device with GPS:

1. Connect your device
2. Run the app
3. Grant location permissions
4. Walk around to see position updates

### On Simulator/Emulator

You can simulate location on iOS Simulator:

1. While app is running, go to **Features > Location > Custom Location**
2. Enter latitude and longitude
3. The app will update to show the simulated position

On Android Emulator:

1. Click the **...** (More) button in the emulator toolbar
2. Select **Location**
3. Enter coordinates or use the map to set a location

## Code Structure

```
lib/
  main.dart              # Main application file

Key Components:
- MyApp                  # Root widget with MaterialApp
- ProximiioExample       # Main example widget with TabBar
- _ProximiioExampleState # State management for the example

Methods:
- _requestPermissions()  # Handle permission requests
- _initProximiio()      # Initialize Proximiio SDK
- _buildDataView()      # Build the data tab UI
- _buildMapView()       # Build the map tab UI
```

## Key Code Snippets

### Authorization

```dart
final state = await FlutterProximiio.authorize(token);
if (state.ready) {
  print('Visitor ID: ${state.visitorId}');
}
```

### Subscribe to Position Updates

```dart
FlutterProximiio.subscribe(
  ProximiioEvents.positionUpdated,
  (ProximiioLocation location) {
    setState(() {
      _location = location;
    });
  },
);
```

### Display Map

```dart
ProximiioMapWidget(
  token: token,
  mapDefaults: {
    'lat': _location.lat,
    'lng': _location.lng,
    'zoom': 18,
  },
  onMapReady: () {
    debugPrint('Map is ready!');
  },
  onFeatureClick: (data) {
    debugPrint('Feature clicked: $data');
  },
)
```

## Troubleshooting

### Permissions Not Granted

If permissions are not granted:
1. Check device settings and enable location permissions
2. Tap "Request Permissions Again" button in the app
3. Make sure Bluetooth is enabled for beacon detection

### Location Not Updating

If location is not updating:
1. Ensure GPS is enabled on your device
2. Try moving to a different location
3. Check that your Proximiio token is valid
4. Look at the logs for any error messages

### Map Not Loading

If the map is not loading:
1. Check your internet connection
2. Verify your Proximiio token is valid
3. Make sure you have configured map access in Proximiio Dashboard
4. Check browser console logs in WebView

### iOS Build Issues

If you encounter iOS build issues:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
```

### Android Build Issues

If you encounter Android build issues:

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
```

## Dependencies

This example uses the following packages:

- `flutter_proximiio` - Core Proximiio indoor positioning plugin
- `flutter_proximiio_map` - Proximiio map visualization plugin

## Learn More

- [Flutter Proximiio Plugin Documentation](https://github.com/proximiio/flutter-proximiio-map/blob/main/README.md)
- [Flutter Proximiio Map Plugin Documentation](https://github.com/proximiio/flutter-proximiio-map/blob/main/README.md)

## Support

For issues and questions:
- GitHub: https://github.com/proximiio/flutter-proximiio
- Proximiio Support: https://proximi.io
