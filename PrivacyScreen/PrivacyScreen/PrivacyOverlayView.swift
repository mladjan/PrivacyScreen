// MARK: - PrivacyOverlayView.swift
// Overlay that progressively obscures content based on gaze deviation.
// Intensity 0.0 = fully visible, 1.0 = fully blacked out / blurred.

import UIKit

final class PrivacyOverlayView: UIView {

    // MARK: - Subviews

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let solidView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let lockIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        let image = UIImage(systemName: "lock.shield.fill", withConfiguration: config)
        let view = UIImageView(image: image)
        view.tintColor = .white.withAlphaComponent(0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.alpha = 0
        return view
    }()

    // MARK: - State

    private var currentMode: PrivacyOverlayMode = .blackout
    private let blurEffect = UIBlurEffect(style: .dark)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        clipsToBounds = true

        addSubview(solidView)
        addSubview(blurView)
        addSubview(lockIcon)

        NSLayoutConstraint.activate([
            solidView.topAnchor.constraint(equalTo: topAnchor),
            solidView.leadingAnchor.constraint(equalTo: leadingAnchor),
            solidView.trailingAnchor.constraint(equalTo: trailingAnchor),
            solidView.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            lockIcon.centerXAnchor.constraint(equalTo: centerXAnchor),
            lockIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Start fully transparent
        solidView.alpha = 0
        blurView.alpha = 0
    }

    // MARK: - Public API

    func configure(mode: PrivacyOverlayMode, showLockIcon: Bool = true) {
        currentMode = mode
        lockIcon.isHidden = !showLockIcon

        switch mode {
        case .blackout:
            solidView.isHidden = false
            blurView.isHidden = true
        case .blur:
            solidView.isHidden = true
            blurView.isHidden = false
            blurView.effect = blurEffect
        }
    }

    /// Set the overlay intensity progressively.
    /// - Parameter intensity: 0.0 = fully visible (no overlay), 1.0 = fully obscured.
    /// - Parameter animated: Smooth spring animation, interruptible between frames.
    func setIntensity(_ intensity: CGFloat, animated: Bool = true) {
        let clamped = min(max(intensity, 0), 1)

        let applyIntensity = {
            switch self.currentMode {
            case .blackout:
                self.solidView.alpha = clamped
            case .blur:
                self.blurView.alpha = clamped
            }
            // Lock icon fades in above 0.5 intensity, fully visible at 1.0
            let lockAlpha = max(0, (clamped - 0.5) * 2.0)
            self.lockIcon.alpha = lockAlpha
        }

        if animated {
            // Critically-damped spring with short response time.
            // At 8+ FPS each frame interrupts the previous animation via
            // .beginFromCurrentState, producing a smooth continuous blend.
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                usingSpringWithDamping: 1.0,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: applyIntensity
            )
        } else {
            applyIntensity()
        }
    }
}
