// MARK: - CameraPipeline.swift
// AVCaptureSession + Vision processing on a serial background queue.
// Handles frame throttling, backpressure (late frames dropped), and FPS switching.

@preconcurrency import AVFoundation
import Vision
import CoreMedia

nonisolated final class CameraPipeline: NSObject, @unchecked Sendable {

    // MARK: - Properties

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(
        label: "net.mladjan.privacyscreen.processing",
        qos: .userInitiated
    )

    private let sequenceHandler = VNSequenceRequestHandler()
    private var lastProcessedTime: CFTimeInterval = 0
    private var targetInterval: TimeInterval = 0.5 // 1 / normalFPS

    private var _config: PrivacyMonitorConfiguration
    var config: PrivacyMonitorConfiguration {
        get { _config }
        set {
            _config = newValue
            targetInterval = 1.0 / newValue.normalFPS
        }
    }

    /// Called on processingQueue with each analysis result.
    var onAnalysisResult: (@Sendable (FaceAnalysisResult) -> Void)?

    // MARK: - Init

    init(config: PrivacyMonitorConfiguration) {
        self._config = config
        self.targetInterval = 1.0 / config.normalFPS
        super.init()
    }

    // MARK: - Public

    /// Configure and start the capture session on the processing queue
    /// to avoid blocking the main thread.
    func startCapture() throws {
        try configureCaptureSession()
        processingQueue.async { [captureSession] in
            guard !captureSession.isRunning else { return }
            captureSession.startRunning()
        }
    }

    func stopCapture() {
        processingQueue.async { [captureSession] in
            guard captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    func setTargetFPS(_ fps: Double) {
        targetInterval = 1.0 / max(fps, 0.5)
    }

    // MARK: - Session configuration

    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // Low resolution preset for battery efficiency
        if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        } else {
            captureSession.sessionPreset = .low
        }

        // Front camera
        guard let frontCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw CameraPipelineError.noFrontCamera
        }

        let input = try AVCaptureDeviceInput(device: frontCamera)
        guard captureSession.canAddInput(input) else {
            throw CameraPipelineError.cannotAddInput
        }
        captureSession.addInput(input)

        // Video output — use native camera pixel format to avoid conversion overhead
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraPipelineError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

nonisolated extension CameraPipeline: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()

        // Throttle: skip frames until enough time has passed
        guard now - lastProcessedTime >= targetInterval else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Run Vision face detection synchronously on this serial queue.
        // alwaysDiscardsLateVideoFrames ensures we never build up backpressure.
        let request = VNDetectFaceRectanglesRequest()

        do {
            // .leftMirrored = front camera in portrait orientation
            try sequenceHandler.perform(
                [request],
                on: pixelBuffer,
                orientation: .leftMirrored
            )
        } catch {
            return
        }

        let observations = request.results ?? []
        let result = FaceAnalyzer.analyze(
            observations: observations,
            config: _config,
            timestamp: now
        )

        onAnalysisResult?(result)
    }
}

// MARK: - Errors

enum CameraPipelineError: Error, Sendable {
    case noFrontCamera
    case cannotAddInput
    case cannotAddOutput
}
