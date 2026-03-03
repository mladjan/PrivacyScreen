# PrivacyScreen

An iOS privacy protection feature that uses the front camera and on-device Vision framework to detect when someone is peeking at your screen and when you look away -- then progressively obscures sensitive content in real time.

[![Demo](https://img.youtube.com/vi/L4OUf8VFgLk/0.jpg)](https://youtube.com/shorts/L4OUf8VFgLk)

## Features

- **Gaze-based progressive overlay** -- content fades to black (or blur) as you turn your head away from the screen. Fully transparent when looking straight, fully obscured when looking far off.
- **Peek detection** -- detects secondary faces in the camera frame. Shows a warning banner and optionally blacks out content when someone is confirmed peeking.
- **On-device only** -- all processing uses Apple's Vision framework locally. No images are stored or transmitted.
- **Battery friendly** -- low-resolution capture (640x480), adaptive FPS (8 normal / 15 burst), serial queue with frame dropping.
- **Configurable** -- sensitivity (normal/high), overlay mode (blackout/blur), peek policy (warn only / blackout on peek), all timing thresholds tunable.

## Architecture

```
PrivacyScreenController      Public API -- install overlay, start/stop monitoring
    └── PrivacyMonitor        Orchestrator -- owns camera pipeline + state machine
            ├── CameraPipeline        AVCaptureSession + Vision face detection
            ├── FaceAnalyzer          Computes gaze deviation + secondary face detection
            └── PrivacyMonitorStateMachine   Peek detection state: idle → monitoring → confirming → alert

UI:
    ├── PrivacyOverlayView    Progressive blackout/blur overlay (driven by gaze deviation)
    └── PeekBannerView        "Someone may be peeking" warning toast
```

### Key types

| File | Purpose |
|------|---------|
| `PrivacyMonitorTypes.swift` | Enums, configuration struct, `FaceAnalysisResult` |
| `FaceAnalyzer.swift` | Vision-based face analysis -- primary face selection, gaze deviation, secondary face detection |
| `CameraPipeline.swift` | AVCaptureSession setup, frame throttling, Vision request dispatch |
| `PrivacyMonitorStateMachine.swift` | Peek detection state machine with burst FPS escalation |
| `PrivacyMonitor.swift` | Orchestrator -- maps gaze deviation to overlay intensity, executes state machine actions |
| `PrivacyOverlayView.swift` | Blackout/blur overlay with spring-animated intensity changes |
| `PeekBannerView.swift` | Slide-in warning banner with cooldown |
| `PrivacyScreenController.swift` | Public-facing controller -- `install(overlayOn:bannerOn:)`, `startMonitoring()`, `stopMonitoring()` |

## How it works

1. **Gaze deviation** is computed from the primary face's yaw and pitch angles (from `VNFaceObservation`). A deviation of 0.0 means looking straight at the phone; 1.0 means at the configured threshold.
2. **Overlay intensity** kicks in only when deviation exceeds 1.0 (past threshold). Deviation 1.0-2.0 maps linearly to overlay intensity 0.0-1.0.
3. **Peek detection** runs in parallel: if a secondary face (above minimum size) persists for 400ms, the state machine transitions to alert and triggers the banner / forced blackout.
4. **Animations** use 0.18s critically-damped springs with `.beginFromCurrentState`, so rapid frame updates (8-15 FPS) produce smooth continuous blending.

## Integration

```swift
// 1. Create the controller
let privacyController = PrivacyScreenController()

// 2. Install overlay on a specific view, banner on the parent
privacyController.install(overlayOn: sensitiveCardView, bannerOn: view)

// 3. Start monitoring
privacyController.startMonitoring(
    sensitivity: .normal,
    mode: .blackout,
    peekPolicy: .warnOnly
)

// 4. Stop when leaving the screen
privacyController.stopMonitoring()
```

## Requirements

- iOS 26.2+
- `NSCameraUsageDescription` in Info.plist (added via build settings)
- Front-facing camera access

## Demo

The included `DemoViewController` shows a styled card with sample sensitive data, a toggle to enable/disable monitoring, and a settings sheet for configuring sensitivity, overlay mode, and peek policy.

## Tests

17 unit tests covering the state machine (peek detection transitions, cooldowns, blackout-on-peek policy) and face analyzer (gaze deviation computation, primary face selection, secondary face detection).

```bash
xcodebuild test -scheme PrivacyScreen -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
