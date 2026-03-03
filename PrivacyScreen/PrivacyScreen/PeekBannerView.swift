// MARK: - PeekBannerView.swift
// Subtle toast/banner: "Privacy warning: someone may be peeking."
// Slides in from top, auto-hides after configurable duration, respects cooldown.

import UIKit

final class PeekBannerView: UIView {

    // MARK: - Configuration

    var displayDuration: TimeInterval = 3.0
    var cooldownDuration: TimeInterval = 5.0

    // MARK: - Subviews

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "eye.trianglebadge.exclamationmark", withConfiguration: config)
        let view = UIImageView(image: image)
        view.tintColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.text = "Privacy warning: someone may be peeking"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - State

    private(set) var isShowing = false
    private var lastDismissTime: CFTimeInterval = 0
    private var hideWorkItem: DispatchWorkItem?
    private var topConstraint: NSLayoutConstraint?

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

        addSubview(containerView)
        containerView.addSubview(iconView)
        containerView.addSubview(label)

        // Start fully hidden: above the top edge + invisible
        containerView.alpha = 0
        let top = containerView.bottomAnchor.constraint(equalTo: topAnchor, constant: 0)
        topConstraint = top

        NSLayoutConstraint.activate([
            top,
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Public API

    func showBanner() {
        let now = CACurrentMediaTime()

        // Respect cooldown
        if now - lastDismissTime < cooldownDuration, lastDismissTime > 0 {
            return
        }

        guard !isShowing else { return }
        isShowing = true

        // Cancel pending hide
        hideWorkItem?.cancel()

        // Swap anchor: pin container's top below the safe area + title bar
        layoutIfNeeded()
        topConstraint?.isActive = false
        let shown = containerView.topAnchor.constraint(
            equalTo: safeAreaLayoutGuide.topAnchor, constant: 56
        )
        shown.isActive = true
        topConstraint = shown

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState]
        ) {
            self.containerView.alpha = 1
            self.layoutIfNeeded()
        }

        // Schedule auto-hide
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideBanner()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }

    func hideBanner() {
        guard isShowing else { return }
        isShowing = false
        hideWorkItem?.cancel()
        lastDismissTime = CACurrentMediaTime()

        // Swap anchor: pin container's bottom to view's top (fully above)
        topConstraint?.isActive = false
        let hidden = containerView.bottomAnchor.constraint(equalTo: topAnchor, constant: 0)
        hidden.isActive = true
        topConstraint = hidden

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            self.containerView.alpha = 0
            self.layoutIfNeeded()
        }
    }
}
