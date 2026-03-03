// MARK: - PrivacyMonitor.swift
// Main orchestrator. Owns the camera pipeline, state machine, and drives UI actions.
// Gaze → continuous overlay intensity. Peek detection → banner + optional forced blackout.

import AVFoundation
import QuartzCore

final class PrivacyMonitor {

    // MARK: - Public callbacks

    /// Called each frame with the overlay intensity (0.0–1.0).
    var onOverlayIntensityChanged: ((CGFloat) -> Void)?
    var onPeekChanged: ((Bool) -> Void)?
    var onFPSChanged: ((Double) -> Void)?

    // MARK: - State

    private(set) var isMonitoring = false
    private var stateMachine: PrivacyMonitorStateMachine
    private let cameraPipeline: CameraPipeline
    private var config: PrivacyMonitorConfiguration

    /// When true, peek policy forces full blackout regardless of gaze.
    private var peekBlackoutForced = false

    // MARK: - Init

    init(config: PrivacyMonitorConfiguration = .default()) {
        self.config = config
        self.stateMachine = PrivacyMonitorStateMachine(config: config)
        self.cameraPipeline = CameraPipeline(config: config)
    }

    // MARK: - Public API

    func startMonitoring() {
        guard !isMonitoring else { return }

        checkCameraPermission { [weak self] granted in
            guard let self, granted else { return }
            self.beginMonitoring()
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        peekBlackoutForced = false

        cameraPipeline.stopCapture()
        let actions = stateMachine.stop()
        execute(actions)
        onOverlayIntensityChanged?(0)
    }

    func updateConfiguration(_ config: PrivacyMonitorConfiguration) {
        self.config = config
        self.stateMachine.config = config
        self.cameraPipeline.config = config
    }

    // MARK: - Permission

    private func checkCameraPermission(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Internal

    private func beginMonitoring() {
        isMonitoring = true
        peekBlackoutForced = false

        let actions = stateMachine.start()
        execute(actions)

        cameraPipeline.onAnalysisResult = { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleAnalysisResult(result)
            }
        }

        do {
            try cameraPipeline.startCapture()
        } catch {
            isMonitoring = false
        }
    }

    private func handleAnalysisResult(_ result: FaceAnalysisResult) {
        guard isMonitoring else { return }

        // 1. Run peek detection state machine
        let actions = stateMachine.process(result)
        execute(actions)

        // 2. Overlay intensity driven only by peek detection.
        //    No gaze-angle fading — only peekBlackoutForced triggers overlay.
        let intensity: CGFloat = peekBlackoutForced ? 1.0 : 0.0

        #if DEBUG
        print(String(
            format: "[PrivacyMonitor] faces=%d yaw=%.3f pitch=%.3f deviation=%.3f intensity=%.3f",
            result.faceCount,
            result.primaryFaceYaw ?? 0,
            result.primaryFacePitch ?? 0,
            result.gazeDeviation,
            intensity
        ))
        #endif

        onOverlayIntensityChanged?(intensity)
    }

    // MARK: - Action execution

    private func execute(_ actions: [PrivacyMonitorStateMachine.Action]) {
        for action in actions {
            switch action {
            case .switchToBurstFPS:
                cameraPipeline.setTargetFPS(config.burstFPS)
                onFPSChanged?(config.burstFPS)

            case .switchToNormalFPS:
                cameraPipeline.setTargetFPS(config.normalFPS)
                onFPSChanged?(config.normalFPS)

            case .showPeekBanner:
                onPeekChanged?(true)

            case .hidePeekBanner:
                onPeekChanged?(false)

            case .forcePeekBlackout:
                peekBlackoutForced = true

            case .releasePeekBlackout:
                peekBlackoutForced = false
            }
        }
    }
}
