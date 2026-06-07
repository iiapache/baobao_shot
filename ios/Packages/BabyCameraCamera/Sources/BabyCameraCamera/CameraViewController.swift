import AVFoundation
import BabyCameraPermissions
import UIKit

/// UIKit 取景控制器：预览、前后摄、闪光灯、网格、水平仪、倒计时。
@MainActor
public final class CameraViewController: UIViewController {
    public var onCaptureRequested: (() -> Void)?
    public var onStartupCompleted: ((TimeInterval) -> Void)?

    /// 当前取景框信息浮层（宝宝小名 + 成长天数）。
    public private(set) var overlayInfo: CameraOverlayInfo?

    private let cameraState: CameraState
    private let session: any CameraSessionControlling
    private let permissionRouting: PermissionRouting

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let infoOverlay = OverlayView()
    private let gridOverlay = GridOverlayView()
    private let levelOverlay = LevelOverlayView()
    private let countdownOverlay = CountdownOverlayView()
    private let permissionBanner = UILabel()

    private var countdownTimer: Timer?
    private var startupTimestamp: CFAbsoluteTime?

    private lazy var switchCameraButton = makeToolbarButton(systemName: "camera.rotate")
    private lazy var flashButton = makeToolbarButton(systemName: "bolt.circle")
    private lazy var gridButton = makeToolbarButton(systemName: "grid")
    private lazy var levelButton = makeToolbarButton(systemName: "circle.line.horizontal")
    private lazy var countdownButton = makeToolbarButton(systemName: "timer")
    private lazy var shutterButton = makeShutterButton()

    public init(
        cameraState: CameraState = CameraState(),
        session: any CameraSessionControlling = CameraSession(),
        permissionManager: any PermissionManager = DefaultPermissionManager()
    ) {
        self.cameraState = cameraState
        self.session = session
        self.permissionRouting = PermissionRouting(manager: permissionManager)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPreviewLayer()
        setupOverlays()
        setupToolbar()
        applyConfiguration(cameraState.configuration)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        gridOverlay.frame = view.bounds
        levelOverlay.frame = view.bounds
        countdownOverlay.frame = CGRect(
            x: 0,
            y: view.bounds.midY - 60,
            width: view.bounds.width,
            height: 120
        )
    }

    /// 更新顶部信息浮层；切换宝宝或跨日时可重新调用。
    public func updateOverlayInfo(_ info: CameraOverlayInfo?) {
        overlayInfo = info
        cameraState.setOverlayInfo(info)
        infoOverlay.update(info: info)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await startCameraIfAuthorized() }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCountdown()
        levelOverlay.stopMonitoring()
        session.stopRunning()
    }

    // MARK: - Permission & session

    private func startCameraIfAuthorized() async {
        let status = await permissionRouting.ensureAuthorized(.camera)
        guard status == .authorized else {
            cameraState.setPermissionDenied(true)
            showPermissionBanner()
            return
        }

        cameraState.setPermissionDenied(false)
        permissionBanner.isHidden = true
        startupTimestamp = CFAbsoluteTimeGetCurrent()
        cameraState.resetFirstFrame()

        session.onFirstPreviewFrame = { [weak self] in
            Task { @MainActor in
                self?.handleFirstPreviewFrame()
            }
        }

        do {
            try session.configure(with: cameraState.configuration)
            try session.startRunning()
            cameraState.setLifecycle(.running)
            updateLevelMonitoring()
        } catch {
            cameraState.setLifecycle(.failed(.configurationFailed))
        }
    }

    private func handleFirstPreviewFrame() {
        guard !cameraState.viewState.hasReceivedFirstFrame else { return }
        cameraState.markFirstFrameReceived()

        if let start = startupTimestamp {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            onStartupCompleted?(elapsed)
        }
    }

    private func showPermissionBanner() {
        permissionBanner.isHidden = false
    }

    // MARK: - UI setup

    private func setupPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: session.captureSession)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func setupOverlays() {
        permissionBanner.translatesAutoresizingMaskIntoConstraints = false
        permissionBanner.numberOfLines = 0
        permissionBanner.textAlignment = .center
        permissionBanner.textColor = .white
        permissionBanner.font = .preferredFont(forTextStyle: .body)
        permissionBanner.text = "需要相机权限才能拍摄，请在系统设置中开启。"
        permissionBanner.isHidden = true

        infoOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoOverlay)

        for overlay in [gridOverlay, levelOverlay, countdownOverlay, permissionBanner] {
            overlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(overlay)
        }

        NSLayoutConstraint.activate([
            infoOverlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            infoOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            permissionBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            permissionBanner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            gridOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            gridOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            levelOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            levelOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            levelOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            levelOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupToolbar() {
        let toolbar = UIStackView(arrangedSubviews: [
            flashButton,
            gridButton,
            shutterButton,
            levelButton,
            countdownButton,
            switchCameraButton,
        ])
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.distribution = .equalSpacing
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72),
        ])

        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        gridButton.addTarget(self, action: #selector(gridTapped), for: .touchUpInside)
        levelButton.addTarget(self, action: #selector(levelTapped), for: .touchUpInside)
        countdownButton.addTarget(self, action: #selector(countdownTapped), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        configureCameraAccessibility()
    }

    private func configureCameraAccessibility() {
        view.accessibilityIdentifier = "cameraViewController"

        permissionBanner.accessibilityIdentifier = "cameraPermissionBanner"
        permissionBanner.accessibilityLabel = "需要相机权限才能拍摄"
        permissionBanner.accessibilityHint = "请在系统设置中开启相机权限"

        configureToolbarButton(
            switchCameraButton,
            identifier: "cameraSwitchButton",
            label: "切换摄像头",
            hint: "在前置与后置摄像头之间切换"
        )
        configureToolbarButton(
            flashButton,
            identifier: "cameraFlashButton",
            label: "闪光灯",
            hint: "循环切换闪光灯自动、开启与关闭"
        )
        configureToolbarButton(
            gridButton,
            identifier: "cameraGridButton",
            label: "三分法网格",
            hint: "显示或隐藏构图辅助网格线"
        )
        configureToolbarButton(
            levelButton,
            identifier: "cameraLevelButton",
            label: "水平仪",
            hint: "显示或隐藏水平参考线"
        )
        configureToolbarButton(
            countdownButton,
            identifier: "cameraCountdownButton",
            label: "倒计时",
            hint: "设置拍照前的倒计时秒数"
        )

        shutterButton.accessibilityIdentifier = "cameraShutterButton"
        shutterButton.accessibilityLabel = "拍照"
        shutterButton.accessibilityHint = "拍摄一张照片"

        countdownOverlay.accessibilityIdentifier = "cameraCountdownOverlay"
    }

    private func configureToolbarButton(
        _ button: UIButton,
        identifier: String,
        label: String,
        hint: String
    ) {
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = label
        button.accessibilityHint = hint
    }

    private func makeToolbarButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: systemName)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func makeShutterButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 36
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        return button
    }

    // MARK: - Configuration

    private func applyConfiguration(_ configuration: CameraConfiguration) {
        gridOverlay.isHidden = !configuration.showsGrid
        levelOverlay.isHidden = !configuration.showsLevel
        updateLevelMonitoring()
        updateFlashButton(configuration.flashMode)
        updateGridButton(configuration.showsGrid)
        updateLevelButton(configuration.showsLevel)
        updateCountdownButton(configuration.countdown)
    }

    private func updateLevelMonitoring() {
        if cameraState.configuration.showsLevel {
            levelOverlay.startMonitoring()
        } else {
            levelOverlay.stopMonitoring()
        }
    }

    private func updateFlashButton(_ mode: CameraFlashMode) {
        let symbol: String
        switch mode {
        case .auto: symbol = "bolt.circle"
        case .on: symbol = "bolt.fill"
        case .off: symbol = "bolt.slash.fill"
        }
        flashButton.setImage(UIImage(systemName: symbol), for: .normal)
    }

    private func updateGridButton(_ enabled: Bool) {
        gridButton.tintColor = enabled ? .systemYellow : .white
    }

    private func updateLevelButton(_ enabled: Bool) {
        levelButton.tintColor = enabled ? .systemYellow : .white
    }

    private func updateCountdownButton(_ countdown: CameraCountdown) {
        let title: String
        switch countdown {
        case .off: title = "关"
        case .three: title = "3s"
        case .ten: title = "10s"
        }
        countdownButton.setTitle(title, for: .normal)
        countdownButton.setImage(nil, for: .normal)
        countdownButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    }

    // MARK: - Actions

    @objc private func switchCameraTapped() {
        cameraState.updateConfiguration { $0.toggleCamera() }
        applyConfiguration(cameraState.configuration)
        try? session.switchCamera()
    }

    @objc private func flashTapped() {
        cameraState.updateConfiguration { $0.cycleFlashMode() }
        applyConfiguration(cameraState.configuration)
        try? session.setFlashMode(cameraState.configuration.flashMode)
    }

    @objc private func gridTapped() {
        cameraState.updateConfiguration { $0.showsGrid.toggle() }
        applyConfiguration(cameraState.configuration)
    }

    @objc private func levelTapped() {
        cameraState.updateConfiguration { $0.showsLevel.toggle() }
        applyConfiguration(cameraState.configuration)
    }

    @objc private func countdownTapped() {
        cameraState.updateConfiguration { $0.cycleCountdown() }
        applyConfiguration(cameraState.configuration)
    }

    @objc private func shutterTapped() {
        guard !cameraState.viewState.isCountingDown else { return }
        let countdown = cameraState.configuration.countdown
        guard countdown.isEnabled else {
            onCaptureRequested?()
            return
        }
        startCountdown(seconds: countdown.rawValue)
    }

    // MARK: - Countdown

    private func startCountdown(seconds: Int) {
        stopCountdown()
        var remaining = seconds
        cameraState.setCountdownRemaining(remaining)
        countdownOverlay.show(seconds: remaining)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            remaining -= 1
            if remaining > 0 {
                self.cameraState.setCountdownRemaining(remaining)
                self.countdownOverlay.show(seconds: remaining)
            } else {
                self.stopCountdown()
                self.onCaptureRequested?()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        cameraState.setCountdownRemaining(nil)
        countdownOverlay.hide()
    }
}
