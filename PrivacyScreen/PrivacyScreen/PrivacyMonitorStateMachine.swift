// MARK: - PrivacyMonitorStateMachine.swift
// Pure state machine for peek detection only.
// Gaze-based overlay intensity is now continuous and handled by PrivacyMonitor directly.
// Fully unit-testable: feed FaceAnalysisResult, get back [Action].

import Foundation

struct PrivacyMonitorStateMachine: Sendable {

    // MARK: - Action

    enum Action: Sendable, Equatable {
        case switchToBurstFPS
        case switchToNormalFPS
        case showPeekBanner
        case hidePeekBanner
        /// Force full overlay when peekPolicy == .blackoutOnPeek and peek is active.
        case forcePeekBlackout
        /// Release the forced blackout when peek ends.
        case releasePeekBlackout
    }

    // MARK: - Current state

    private(set) var monitorState: MonitorState = .idle

    // MARK: - Timing trackers

    private var secondaryFaceFirstSeen: CFTimeInterval?
    private var alertEndedAt: CFTimeInterval?

    var config: PrivacyMonitorConfiguration

    // MARK: - Lifecycle

    init(config: PrivacyMonitorConfiguration) {
        self.config = config
    }

    mutating func start() -> [Action] {
        monitorState = .monitoring
        secondaryFaceFirstSeen = nil
        alertEndedAt = nil
        return [.hidePeekBanner, .releasePeekBlackout, .switchToNormalFPS]
    }

    mutating func stop() -> [Action] {
        monitorState = .idle
        secondaryFaceFirstSeen = nil
        alertEndedAt = nil
        return [.hidePeekBanner, .releasePeekBlackout, .switchToNormalFPS]
    }

    // MARK: - Process a frame result

    mutating func process(_ result: FaceAnalysisResult) -> [Action] {
        guard monitorState != .idle else { return [] }

        let now = result.timestamp

        switch monitorState {

        case .idle:
            return []

        case .monitoring:
            if result.hasSecondaryFace {
                secondaryFaceFirstSeen = now
                monitorState = .confirming
                return [.switchToBurstFPS]
            }
            secondaryFaceFirstSeen = nil
            return []

        case .confirming:
            if result.hasSecondaryFace {
                if let firstSeen = secondaryFaceFirstSeen,
                   now - firstSeen >= config.peekConfirmDuration {
                    monitorState = .alert
                    var actions: [Action] = [.showPeekBanner]
                    if config.peekPolicy == .blackoutOnPeek {
                        actions.append(.forcePeekBlackout)
                    }
                    return actions
                }
                return []
            } else {
                secondaryFaceFirstSeen = nil
                monitorState = .monitoring
                return [.switchToNormalFPS]
            }

        case .alert:
            if result.hasSecondaryFace {
                alertEndedAt = nil
                return []
            } else {
                if alertEndedAt == nil {
                    alertEndedAt = now
                }
                if let ended = alertEndedAt,
                   now - ended >= config.alertCooldown {
                    monitorState = .monitoring
                    alertEndedAt = nil
                    secondaryFaceFirstSeen = nil
                    var actions: [Action] = [.switchToNormalFPS, .hidePeekBanner]
                    if config.peekPolicy == .blackoutOnPeek {
                        actions.append(.releasePeekBlackout)
                    }
                    return actions
                }
                return []
            }
        }
    }
}
