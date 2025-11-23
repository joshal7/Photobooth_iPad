# Photobooth App Walkthrough

## Overview
The iPad Photobooth app has been implemented as a Swift Package. It includes a `MockCameraClient` to allow testing without physical hardware.

## Verification Steps

### 1. Open in Xcode
1.  Open the `PhotoboothApp` folder in Xcode.
2.  Xcode should recognize it as a Swift Package.
3.  To run it, you may need to create a dummy iOS App target and import this package, or use Swift Playgrounds.
    *Alternatively, since I provided the source files, you can drag the `Sources` folder into a new iOS App project.*

### 2. Mock Mode Verification
The app is currently configured to use `MockCameraClient` by default (controlled by `StateMachine.useMockCamera`).

1.  **Launch the App**: You should see the "Connecting to Camera..." spinner, followed quickly by the "TAP TO START" screen (Idle State).
2.  **Start Session**: Tap anywhere on the screen.
3.  **Countdown**: You should see a countdown (5s).
4.  **Capture**: The screen will flash white (simulating capture).
5.  **Repeat**: This will repeat 3 times (as per config) with a 2s interval.
6.  **Review**: After capturing, the app will show the captured images (solid colors in Mock mode) for 4 seconds each.
7.  **Reset**: The app will return to the "TAP TO START" screen.

### 3. Configuration
You can modify default settings in `ConfigManager.swift`:
- `initialCountdownSec`
- `interShotCountdownSec`
- `photoCount`

### 4. Real Hardware
To test with a real Sony A7R II:
1.  Connect iPad to Camera Wi-Fi.
2.  Change `StateMachine.useMockCamera` to `false`.
3.  Run the app.

## Artifacts
- **Source Code**: `PhotoboothApp/Sources`
- **Package Definition**: `PhotoboothApp/Package.swift`
