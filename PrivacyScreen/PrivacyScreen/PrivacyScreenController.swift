// MARK: - PrivacyScreenController.swift
// High-level API that a UIViewController uses to add privacy protection.
//
// Usage:
//   let controller = PrivacyScreenController()
//   controller.install(overlayOn: sensitiveCardView, bannerOn: view)
//   controller.startMonitoring(sensitivity: .normal, mode: .blackout) { isPeeking in
//       print("Peek state: \(isPeeking)")
//   }
//   // Later:
//   controller.stopMonitoring()

import UIKit

final class PrivacyScreenController {

    // MARK: - Properties

    private let monitor: PrivacyMonitor
    private let overlayView = PrivacyOverlayView()
    private let bannerView = PeekBannerView()

    private(set) var isEnabled = false

    // MARK: - Init

    init() {
        self.monitor = PrivacyMonitor()
    }

    // MARK: - Installation

    /// Install the overlay on a specific sensitive view, and the peek banner on a parent view.
    /// - Parameters:
    ///   - overlayTarget: The view to obscure (e.g., a card with sensitive data).
    ///   - bannerParent: The view where the peek banner appears (typically the VC's root view).
    func install(overlayOn overlayTarget: UIView, bannerOn bannerParent: UIView) {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayTarget.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: overlayTarget.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: overlayTarget.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: overlayTarget.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: overlayTarget.bottomAnchor),
        ])

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerParent.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: bannerParent.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: bannerParent.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: bannerParent.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bannerParent.bottomAnchor),
        ])
    }

    // MARK: - Public API

    /// Start privacy monitoring.
    func startMonitoring(
        sensitivity: PrivacyMonitorSensitivity = .normal,
        mode: PrivacyOverlayMode = .blackout,
        peekPolicy: PeekPolicy = .warnOnly,
        showLockIcon: Bool = true,
        onPeekChanged: ((Bool) -> Void)? = nil
    ) {
        var config = PrivacyMonitorConfiguration.default(sensitivity: sensitivity)
        config.overlayMode = mode
        config.peekPolicy = peekPolicy
        monitor.updateConfiguration(config)

        overlayView.configure(mode: mode, showLockIcon: showLockIcon)
        bannerView.displayDuration = config.bannerDisplayDuration
        bannerView.cooldownDuration = config.bannerCooldown

        monitor.onOverlayIntensityChanged = { [weak self] intensity in
            self?.overlayView.setIntensity(intensity)
        }

        monitor.onPeekChanged = { [weak self] isPeeking in
            if isPeeking {
                self?.bannerView.showBanner()
            } else {
                self?.bannerView.hideBanner()
            }
            onPeekChanged?(isPeeking)
        }

        isEnabled = true
        monitor.startMonitoring()
    }

    /// Stop privacy monitoring. Clears overlay.
    func stopMonitoring() {
        isEnabled = false
        monitor.stopMonitoring()
        overlayView.setIntensity(0)
        bannerView.hideBanner()
    }

    /// Enable or disable for sensitive screens. Convenience toggle.
    func setEnabledForSensitiveScreen(_ enabled: Bool) {
        if enabled && !isEnabled {
            startMonitoring()
        } else if !enabled && isEnabled {
            stopMonitoring()
        }
    }
}
