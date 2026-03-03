// MARK: - PrivacyScreenTests.swift
// Unit tests for the state machine, face analyzer, and gaze deviation logic.

import Testing
import Foundation
import CoreGraphics
@testable import PrivacyScreen

// MARK: - State Machine Tests (peek detection)

struct StateMachineTests {

    private func makeConfig() -> PrivacyMonitorConfiguration {
        .default(sensitivity: .normal)
    }

    private func makeResult(
        faceCount: Int = 1,
        gazeDeviation: CGFloat = 0,
        hasSecondaryFace: Bool = false,
        timestamp: CFTimeInterval = 0
    ) -> FaceAnalysisResult {
        FaceAnalysisResult(
            faceCount: faceCount,
            primaryFaceRect: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            primaryFaceYaw: 0,
            primaryFacePitch: 0,
            gazeDeviation: gazeDeviation,
            hasSecondaryFace: hasSecondaryFace,
            timestamp: timestamp
        )
    }

    // MARK: - Lifecycle

    @Test func startSetsMonitoringState() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        let actions = sm.start()

        #expect(sm.monitorState == .monitoring)
        #expect(actions.contains(.switchToNormalFPS))
    }

    @Test func stopResetsToIdle() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        _ = sm.start()
        let actions = sm.stop()

        #expect(sm.monitorState == .idle)
        #expect(actions.contains(.hidePeekBanner))
        #expect(actions.contains(.releasePeekBlackout))
    }

    @Test func idleIgnoresInput() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        let actions = sm.process(makeResult(timestamp: 1.0))

        #expect(sm.monitorState == .idle)
        #expect(actions.isEmpty)
    }

    // MARK: - Peek detection

    @Test func secondaryFaceTriggersConfirming() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        _ = sm.start()

        let actions = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        #expect(sm.monitorState == .confirming)
        #expect(actions.contains(.switchToBurstFPS))
    }

    @Test func secondaryFaceDisappearingReturnsToMonitoring() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        _ = sm.start()

        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        #expect(sm.monitorState == .confirming)

        let actions = sm.process(makeResult(hasSecondaryFace: false, timestamp: 1.2))
        #expect(sm.monitorState == .monitoring)
        #expect(actions.contains(.switchToNormalFPS))
    }

    @Test func peekConfirmedAfterThreshold() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        _ = sm.start()

        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        #expect(sm.monitorState == .confirming)

        // Before threshold (0.4s)
        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.3))
        #expect(sm.monitorState == .confirming)

        // After threshold
        let actions = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.5))
        #expect(sm.monitorState == .alert)
        #expect(actions.contains(.showPeekBanner))
    }

    @Test func alertCooldownReturnsToMonitoring() {
        var sm = PrivacyMonitorStateMachine(config: makeConfig())
        _ = sm.start()

        // Trigger alert
        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.5))
        #expect(sm.monitorState == .alert)

        // Secondary face gone
        _ = sm.process(makeResult(hasSecondaryFace: false, timestamp: 2.0))
        #expect(sm.monitorState == .alert) // still in cooldown

        // After alertCooldown (1.0s)
        let actions = sm.process(makeResult(hasSecondaryFace: false, timestamp: 3.1))
        #expect(sm.monitorState == .monitoring)
        #expect(actions.contains(.switchToNormalFPS))
        #expect(actions.contains(.hidePeekBanner))
    }

    @Test func blackoutOnPeekPolicy() {
        var config = makeConfig()
        config.peekPolicy = .blackoutOnPeek
        var sm = PrivacyMonitorStateMachine(config: config)
        _ = sm.start()

        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        let actions = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.5))

        #expect(sm.monitorState == .alert)
        #expect(actions.contains(.forcePeekBlackout))
        #expect(actions.contains(.showPeekBanner))
    }

    @Test func blackoutOnPeekReleasedAfterCooldown() {
        var config = makeConfig()
        config.peekPolicy = .blackoutOnPeek
        var sm = PrivacyMonitorStateMachine(config: config)
        _ = sm.start()

        // Trigger alert
        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.0))
        _ = sm.process(makeResult(hasSecondaryFace: true, timestamp: 1.5))

        // Face gone → cooldown → release
        _ = sm.process(makeResult(hasSecondaryFace: false, timestamp: 2.0))
        let actions = sm.process(makeResult(hasSecondaryFace: false, timestamp: 3.1))
        #expect(actions.contains(.releasePeekBlackout))
    }
}

// MARK: - Face Analyzer / Gaze Deviation Tests

struct FaceAnalyzerTests {

    private func makeConfig() -> PrivacyMonitorConfiguration {
        .default(sensitivity: .normal)
    }

    @Test func noObservationsReturnsFullDeviation() {
        let result = FaceAnalyzer.analyze(
            observations: [],
            config: makeConfig(),
            timestamp: 1.0
        )
        #expect(result.faceCount == 0)
        #expect(result.gazeDeviation == 1.0)
        #expect(!result.isLookingStraight)
        #expect(result.primaryFaceRect == nil)
    }

    @Test func configurationDefaults() {
        let normal = PrivacyMonitorConfiguration.default(sensitivity: .normal)
        #expect(normal.yawThreshold == 0.35)
        #expect(normal.normalFPS == 2.0)
        #expect(normal.burstFPS == 8.0)
        #expect(normal.peekConfirmDuration == 0.4)

        let high = PrivacyMonitorConfiguration.default(sensitivity: .high)
        #expect(high.yawThreshold == 0.26)
        #expect(high.minSecondaryFaceWidth == 0.05)
    }

    @Test func gazeDeviationZeroWhenLookingStraight() {
        let config = makeConfig()
        let deviation = FaceAnalyzer.computeGazeDeviation(
            yaw: 0, pitch: 0,
            faceRect: .zero,
            config: config
        )
        #expect(deviation == 0)
    }

    @Test func gazeDeviationOneAtThreshold() {
        let config = makeConfig() // yawThreshold = 0.35
        let deviation = FaceAnalyzer.computeGazeDeviation(
            yaw: 0.35, pitch: 0,
            faceRect: .zero,
            config: config
        )
        #expect(abs(deviation - 1.0) < 0.001)
    }

    @Test func gazeDeviationProportional() {
        let config = makeConfig() // yawThreshold = 0.35
        let half = FaceAnalyzer.computeGazeDeviation(
            yaw: 0.175, pitch: 0,
            faceRect: .zero,
            config: config
        )
        #expect(abs(half - 0.5) < 0.01)
    }

    @Test func gazeDeviationBeyondThreshold() {
        let config = makeConfig()
        let deviation = FaceAnalyzer.computeGazeDeviation(
            yaw: 0.70, pitch: 0,
            faceRect: .zero,
            config: config
        )
        #expect(deviation > 1.0)
    }

    @Test func gazeDeviationUsesMaxOfYawAndPitch() {
        let config = makeConfig() // both thresholds 0.35
        let deviation = FaceAnalyzer.computeGazeDeviation(
            yaw: 0.1, pitch: 0.3,
            faceRect: .zero,
            config: config
        )
        // pitch deviation = 0.3 / 0.35 ≈ 0.857 > yaw deviation = 0.1 / 0.35 ≈ 0.286
        let expected = CGFloat(0.3 / 0.35)
        #expect(abs(deviation - expected) < 0.01)
    }

    @Test func isLookingStraightDerivedFromDeviation() {
        let straight = FaceAnalysisResult(
            faceCount: 1, primaryFaceRect: .zero,
            primaryFaceYaw: 0, primaryFacePitch: 0,
            gazeDeviation: 0.5,
            hasSecondaryFace: false, timestamp: 0
        )
        #expect(straight.isLookingStraight == true)

        let turned = FaceAnalysisResult(
            faceCount: 1, primaryFaceRect: .zero,
            primaryFaceYaw: 0.4, primaryFacePitch: 0,
            gazeDeviation: 1.2,
            hasSecondaryFace: false, timestamp: 0
        )
        #expect(turned.isLookingStraight == false)
    }
}
