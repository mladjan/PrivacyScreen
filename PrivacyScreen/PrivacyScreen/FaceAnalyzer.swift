// MARK: - FaceAnalyzer.swift
// Pure analysis: takes [VNFaceObservation] + config, returns FaceAnalysisResult.
// No camera, no state — just math. Unit-testable.

import Vision
import CoreGraphics

nonisolated enum FaceAnalyzer {

    /// Analyze Vision face observations and produce a minimal derived result.
    /// Called from the camera processing queue — must be nonisolated.
    static func analyze(
        observations: [VNFaceObservation],
        config: PrivacyMonitorConfiguration,
        timestamp: CFTimeInterval
    ) -> FaceAnalysisResult {
        guard !observations.isEmpty else {
            return FaceAnalysisResult(
                faceCount: 0,
                primaryFaceRect: nil,
                primaryFaceYaw: nil,
                primaryFacePitch: nil,
                gazeDeviation: 1.0,
                hasSecondaryFace: false,
                timestamp: timestamp
            )
        }

        // 1. Select primary face: largest + closest to center
        let primary = selectPrimaryFace(observations)

        // 2. Compute continuous gaze deviation (0 = straight, 1 = at threshold)
        let yaw = primary.yaw?.floatValue
        let pitch = primary.pitch?.floatValue
        let deviation = computeGazeDeviation(
            yaw: yaw,
            pitch: pitch,
            faceRect: primary.boundingBox,
            config: config
        )

        // 3. Detect secondary faces
        let hasSecondary = detectSecondaryFace(
            observations: observations,
            primary: primary,
            config: config
        )

        return FaceAnalysisResult(
            faceCount: observations.count,
            primaryFaceRect: primary.boundingBox,
            primaryFaceYaw: yaw,
            primaryFacePitch: pitch,
            gazeDeviation: deviation,
            hasSecondaryFace: hasSecondary,
            timestamp: timestamp
        )
    }

    // MARK: - Primary face selection

    /// Score = 60% area + 40% center proximity. Highest score wins.
    private static func selectPrimaryFace(
        _ observations: [VNFaceObservation]
    ) -> VNFaceObservation {
        let maxDist = sqrt(0.5) // diagonal from center to corner in normalized space
        return observations.max { a, b in
            score(for: a, maxDist: maxDist) < score(for: b, maxDist: maxDist)
        }!
    }

    private static func score(for obs: VNFaceObservation, maxDist: Double) -> Double {
        let rect = obs.boundingBox
        let area = Double(rect.width * rect.height)
        let cx = Double(rect.midX) - 0.5
        let cy = Double(rect.midY) - 0.5
        let dist = sqrt(cx * cx + cy * cy)
        let centerScore = 1.0 - (dist / maxDist)
        return area * 0.6 + centerScore * 0.4
    }

    // MARK: - Gaze deviation (continuous)

    /// Returns 0.0 when looking perfectly straight, 1.0 at threshold, >1.0 beyond.
    /// The caller uses this directly to drive overlay opacity.
    static func computeGazeDeviation(
        yaw: Float?,
        pitch: Float?,
        faceRect: CGRect,
        config: PrivacyMonitorConfiguration
    ) -> CGFloat {
        if let yaw {
            let yawDev = CGFloat(abs(yaw) / config.yawThreshold)
            let pitchDev = pitch.map { CGFloat(abs($0) / config.pitchThreshold) } ?? 0
            return max(yawDev, pitchDev)
        }

        // Fallback heuristic: horizontal face-center offset as deviation proxy.
        let centerX = faceRect.midX
        let offset = abs(centerX - 0.5)
        return CGFloat(offset / 0.2) // 0.2 is the fallback "threshold"
    }

    // MARK: - Secondary face detection

    private static func detectSecondaryFace(
        observations: [VNFaceObservation],
        primary: VNFaceObservation,
        config: PrivacyMonitorConfiguration
    ) -> Bool {
        guard observations.count > 1 else { return false }

        let minWidth = config.minSecondaryFaceWidth

        for obs in observations {
            // Skip the primary face (identity check via bounding box)
            if obs.boundingBox == primary.boundingBox { continue }

            // Must be above minimum size threshold
            if obs.boundingBox.width >= minWidth {
                return true
            }
        }
        return false
    }
}
