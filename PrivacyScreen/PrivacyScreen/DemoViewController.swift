// MARK: - DemoViewController.swift
// Modern demo for Privacy Screen.

import UIKit

// MARK: - Accent color helpers

private extension UIColor {
    static let accent = UIColor(red: 0.35, green: 0.50, blue: 1.0, alpha: 1.0)    // soft blue
    static let accentDim = UIColor(red: 0.35, green: 0.50, blue: 1.0, alpha: 0.12)
    static let surfaceCard = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor(white: 0.97, alpha: 1)
    }
    static let surfaceBottom = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.09, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
    }
    static let bgGradientTop = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1)
            : UIColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1)
    }
    static let bgGradientBottom = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.0, green: 0.0, blue: 0.04, alpha: 1)
            : .white
    }
}

final class DemoViewController: UIViewController {

    // MARK: - Privacy

    private let privacyController = PrivacyScreenController()
    private var selectedSensitivity: PrivacyMonitorSensitivity = .normal
    private var selectedMode: PrivacyOverlayMode = .blur
    private var selectedPolicy: PeekPolicy = .blackoutOnPeek

    // MARK: - Background gradient

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    // MARK: - Top bar

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Privacy Screen"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Protect sensitive data from prying eyes"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var settingsButton: UIButton = {
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let image = UIImage(systemName: "gearshape", withConfiguration: config)
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.tintColor = .accent
        button.backgroundColor = .accentDim
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36),
        ])
        button.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Card

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .surfaceCard
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cardIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = UIImage(systemName: "message.fill", withConfiguration: config)
        let view = UIImageView(image: image)
        view.tintColor = .accent
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let cardHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "Messages"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .accent
        return label
    }()

    private func makeMessageRow(sender: String, message: String, time: String) -> UIView {
        let avatar = UILabel()
        avatar.text = String(sender.prefix(1))
        avatar.font = .systemFont(ofSize: 13, weight: .bold)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = .accent.withAlphaComponent(0.7)
        avatar.layer.cornerRadius = 15
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 30),
            avatar.heightAnchor.constraint(equalToConstant: 30),
        ])

        let nameLabel = UILabel()
        nameLabel.text = sender
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label

        let timeLabel = UILabel()
        timeLabel.text = time
        timeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .tertiaryLabel
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [nameLabel, UIView(), timeLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let msgLabel = UILabel()
        msgLabel.text = message
        msgLabel.font = .systemFont(ofSize: 13, weight: .regular)
        msgLabel.textColor = .secondaryLabel
        msgLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [topRow, msgLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [avatar, textStack])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        return row
    }

    private lazy var dataRows: UIStackView = {
        let rows = UIStackView(arrangedSubviews: [
            makeMessageRow(
                sender: "Alice",
                message: "Hey! The confirmation code is 847291. Don't share it with anyone.",
                time: "2m ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Bob",
                message: "Your account password has been reset to Tr0ub4dor&3. Change it ASAP.",
                time: "15m ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Mom",
                message: "The wifi password at the new place is SunnyDays#2024. See you soon!",
                time: "1h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "David",
                message: "Wire transfer of $8,500 sent to your account ending in 4217.",
                time: "3h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Eve",
                message: "Meeting moved to tomorrow. The door code is 5523#. Don't be late!",
                time: "5h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Frank",
                message: "Your 2FA recovery codes: 8842-1190, 3347-5521, 6619-0037. Store safely.",
                time: "6h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Grace",
                message: "Sent you the API key: sk_live_49dKc8wPm3nT. Rotate it after setup.",
                time: "8h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Henry",
                message: "Insurance claim #PCY-20241087 approved. Payout: $3,200 to your Visa.",
                time: "12h ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Isla",
                message: "Here's the shared drive link with all tax docs. Password is Mar$2024!",
                time: "1d ago"
            ),
            makeSeparator(),
            makeMessageRow(
                sender: "Jack",
                message: "Your flight is confirmed: LAX→JFK, seat 14A. Booking ref XKPT72.",
                time: "1d ago"
            ),
        ])
        rows.axis = .vertical
        rows.spacing = 12
        return rows
    }()

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator.withAlphaComponent(0.3)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    // MARK: - Bottom bar

    private let bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = .surfaceBottom
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let shieldIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let image = UIImage(systemName: "shield.checkered", withConfiguration: config)
        let view = UIImageView(image: image)
        view.tintColor = .accent
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let toggleTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sensitive Mode"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Idle"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let sensitiveToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .accent
        return toggle
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupUI()
        setupPrivacy()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateGradientColors()
    }

    // MARK: - Background

    private func setupBackground() {
        view.layer.insertSublayer(gradientLayer, at: 0)
        updateGradientColors()
    }

    private func updateGradientColors() {
        gradientLayer.colors = [
            UIColor.bgGradientTop.cgColor,
            UIColor.bgGradientBottom.cgColor,
        ]
    }

    // MARK: - Layout

    private func setupUI() {
        // -- Top bar --
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let topBar = UIStackView(arrangedSubviews: [titleStack, UIView(), settingsButton])
        topBar.axis = .horizontal
        topBar.alignment = .center
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        // -- Card --
        let headerRow = UIStackView(arrangedSubviews: [cardIcon, cardHeaderLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(headerRow)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        cardView.addSubview(scrollView)

        dataRows.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(dataRows)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            headerRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            dataRows.topAnchor.constraint(equalTo: scrollView.topAnchor),
            dataRows.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            dataRows.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            dataRows.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            dataRows.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        view.addSubview(cardView)

        // -- Bottom bar --
        let textStack = UIStackView(arrangedSubviews: [toggleTitleLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let iconTextStack = UIStackView(arrangedSubviews: [shieldIcon, textStack])
        iconTextStack.axis = .horizontal
        iconTextStack.spacing = 12
        iconTextStack.alignment = .center

        let bottomContent = UIStackView(arrangedSubviews: [iconTextStack, UIView(), sensitiveToggle])
        bottomContent.axis = .horizontal
        bottomContent.alignment = .center
        bottomContent.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bottomBar)
        bottomBar.addSubview(bottomContent)

        // -- Constraints --
        let margin: CGFloat = 24

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            cardView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            cardView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -16),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomContent.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 20),
            bottomContent.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: margin),
            bottomContent.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -margin),
            bottomContent.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        sensitiveToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
    }

    private func setupPrivacy() {
        privacyController.install(overlayOn: cardView, bannerOn: view)
    }

    // MARK: - Actions

    @objc private func toggleChanged() {
        if sensitiveToggle.isOn {
            privacyController.startMonitoring(
                sensitivity: selectedSensitivity,
                mode: selectedMode,
                peekPolicy: selectedPolicy
            ) { [weak self] isPeeking in
                self?.statusLabel.text = isPeeking ? "Peek detected" : "Monitoring"
                self?.statusLabel.textColor = isPeeking ? .systemRed : .secondaryLabel
            }
            statusLabel.text = "Monitoring"
            statusLabel.textColor = .secondaryLabel
        } else {
            privacyController.stopMonitoring()
            statusLabel.text = "Idle"
            statusLabel.textColor = .secondaryLabel
        }
    }

    @objc private func settingsTapped() {
        let settingsVC = SettingsSheetController(
            sensitivity: selectedSensitivity,
            mode: selectedMode,
            policy: selectedPolicy
        ) { [weak self] sensitivity, mode, policy in
            guard let self else { return }
            self.selectedSensitivity = sensitivity
            self.selectedMode = mode
            self.selectedPolicy = policy
            if self.privacyController.isEnabled {
                self.privacyController.stopMonitoring()
                self.privacyController.startMonitoring(
                    sensitivity: sensitivity,
                    mode: mode,
                    peekPolicy: policy
                ) { [weak self] isPeeking in
                    self?.statusLabel.text = isPeeking ? "Peek detected" : "Monitoring"
                    self?.statusLabel.textColor = isPeeking ? .systemRed : .secondaryLabel
                }
            }
        }
        if let sheet = settingsVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(settingsVC, animated: true)
    }
}

// MARK: - Settings Sheet

private final class SettingsSheetController: UIViewController {

    private let onApply: (PrivacyMonitorSensitivity, PrivacyOverlayMode, PeekPolicy) -> Void

    private let sensitivitySegment = UISegmentedControl(items: ["Normal", "High"])
    private let modeSegment = UISegmentedControl(items: ["Blackout", "Blur"])
    private let policySegment = UISegmentedControl(items: ["Warn Only", "Blackout on Peek"])

    init(
        sensitivity: PrivacyMonitorSensitivity,
        mode: PrivacyOverlayMode,
        policy: PeekPolicy,
        onApply: @escaping (PrivacyMonitorSensitivity, PrivacyOverlayMode, PeekPolicy) -> Void
    ) {
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
        sensitivitySegment.selectedSegmentIndex = sensitivity == .normal ? 0 : 1
        modeSegment.selectedSegmentIndex = mode == .blackout ? 0 : 1
        policySegment.selectedSegmentIndex = policy == .warnOnly ? 0 : 1
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        applySettings()
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let tintColor = UIColor.accent
        sensitivitySegment.selectedSegmentTintColor = tintColor
        modeSegment.selectedSegmentTintColor = tintColor
        policySegment.selectedSegmentTintColor = tintColor

        let normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        for seg in [sensitivitySegment, modeSegment, policySegment] {
            seg.setTitleTextAttributes(normalAttrs, for: .normal)
            seg.setTitleTextAttributes(selectedAttrs, for: .selected)
        }

        let rows = UIStackView(arrangedSubviews: [
            makeRow("shield.lefthalf.filled", "Sensitivity", sensitivitySegment),
            makeRow("eye.slash.fill", "Overlay Mode", modeSegment),
            makeRow("person.2.fill", "Peek Policy", policySegment),
        ])
        rows.axis = .vertical
        rows.spacing = 28

        let stack = UIStackView(arrangedSubviews: [titleLabel, rows])
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func makeRow(_ iconName: String, _ title: String, _ control: UIView) -> UIStackView {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: iconName, withConfiguration: config))
        icon.tintColor = .accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .secondaryLabel

        let header = UIStackView(arrangedSubviews: [icon, label])
        header.axis = .horizontal
        header.spacing = 6
        header.alignment = .center

        let stack = UIStackView(arrangedSubviews: [header, control])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }

    private func applySettings() {
        let sensitivity: PrivacyMonitorSensitivity =
            sensitivitySegment.selectedSegmentIndex == 0 ? .normal : .high
        let mode: PrivacyOverlayMode =
            modeSegment.selectedSegmentIndex == 0 ? .blackout : .blur
        let policy: PeekPolicy =
            policySegment.selectedSegmentIndex == 0 ? .warnOnly : .blackoutOnPeek
        onApply(sensitivity, mode, policy)
    }
}
