// MARK: - PrivacyMonitorTypes.swift
// Core types for the Privacy Screen feature.
//
// Integration guide:
//   1. Create a PrivacyScreenController and call install(on:) with your view.
//   2. Call startMonitoring() when entering a sensitive screen.
//   3. Call stopMonitoring() when leaving.
//   4. Ensure NSCameraUsageDescription is in your Info.plist.
//
// Tunable thresholds live in PrivacyMonitorConfiguration.

import Foundation
import CoreGraphics

// MARK: - Enums

enum PrivacyMonitorSensitivity: Sendable {
    /// Default: yaw +-20deg, min secondary face width 8% of frame
    case normal
    /// Tighter: yaw +-15deg, min secondary face width 5% of frame
    case high
}

enum PrivacyOverlayMode: Sendable {
    case blackout
    case blur
}

enum PeekPolicy: Sendable {
    /// Show warning banner only; content stays visible.
    case warnOnly
    /// Black out content when a secondary face is confirmed.
    case blackoutOnPeek
}

// MARK: - State Machine States

enum MonitorState: Sendable, Equatable {
    /// Feature is off.
    case idle
    /// Scanning at normal FPS. No secondary face suspected.
    case monitoring
    /// Secondary face suspected; burst FPS active, awaiting confirmation.
    case confirming
    /// Peek confirmed (secondary face persisted past threshold).
    case alert
}

// MARK: - Configuration

/// All thresholds are tunable. Defaults are chosen for reasonable iPhone usage.
struct PrivacyMonitorConfiguration: Sendable {
    var sensitivity: PrivacyMonitorSensitivity
    var overlayMode: PrivacyOverlayMode
    var peekPolicy: PeekPolicy

    // -- Head angle thresholds (radians) --
    /// Maximum absolute yaw for "looking straight". ~0.35 rad = ~20 deg.
    var yawThreshold: Float
    /// Maximum absolute pitch for "looking straight". ~0.35 rad = ~20 deg.
    var pitchThreshold: Float

    // -- Face size thresholds (fraction of frame width, 0-1) --
    /// Minimum bounding-box width for a secondary face to count.
    var minSecondaryFaceWidth: CGFloat

    // -- Timing (seconds) --
    /// How long a secondary face must persist before confirming peek.
    var peekConfirmDuration: TimeInterval
    /// Cooldown after peek ends before returning to monitoring.
    var alertCooldown: TimeInterval
    /// How long the peek banner stays visible.
    var bannerDisplayDuration: TimeInterval
    /// Minimum time between consecutive banner appearances.
    var bannerCooldown: TimeInterval

    // -- FPS --
    var normalFPS: Double
    var burstFPS: Double

    static func `default`(sensitivity: PrivacyMonitorSensitivity = .normal) -> Self {
        switch sensitivity {
        case .normal:
            return PrivacyMonitorConfiguration(
                sensitivity: .normal,
                overlayMode: .blackout,
                peekPolicy: .warnOnly,
                yawThreshold: 0.35,
                pitchThreshold: 0.35,
                minSecondaryFaceWidth: 0.08,
                peekConfirmDuration: 0.4,
                alertCooldown: 1.0,
                bannerDisplayDuration: 3.0,
                bannerCooldown: 5.0,
                normalFPS: 8.0,
                burstFPS: 15.0
            )
        case .high:
            return PrivacyMonitorConfiguration(
                sensitivity: .high,
                overlayMode: .blackout,
                peekPolicy: .warnOnly,
                yawThreshold: 0.26,
                pitchThreshold: 0.26,
                minSecondaryFaceWidth: 0.05,
                peekConfirmDuration: 0.3,
                alertCooldown: 0.8,
                bannerDisplayDuration: 3.0,
                bannerCooldown: 5.0,
                normalFPS: 10.0,
                burstFPS: 15.0
            )
        }
    }
}

// MARK: - Face Analysis Result

/// Minimal derived data from a single Vision pass. No images stored.
struct FaceAnalysisResult: Sendable {
    let faceCount: Int
    let primaryFaceRect: CGRect?
    /// Yaw in radians from VNFaceObservation. Positive = looking right.
    let primaryFaceYaw: Float?
    /// Pitch in radians. Positive = looking up.
    let primaryFacePitch: Float?
    /// 0.0 = looking perfectly straight. 1.0 = at threshold. >1.0 = beyond threshold.
    /// Used to drive progressive overlay intensity.
    let gazeDeviation: CGFloat
    let hasSecondaryFace: Bool
    let timestamp: CFTimeInterval

    /// Convenience: deviation < 1.0 means user is roughly looking at the phone.
    var isLookingStraight: Bool { gazeDeviation < 1.0 }

    static let empty = FaceAnalysisResult(
        faceCount: 0,
        primaryFaceRect: nil,
        primaryFaceYaw: nil,
        primaryFacePitch: nil,
        gazeDeviation: 1.0,
        hasSecondaryFace: false,
        timestamp: 0
    )
}
