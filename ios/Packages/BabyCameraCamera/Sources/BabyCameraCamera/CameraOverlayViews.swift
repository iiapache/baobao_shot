import CoreMotion
import UIKit

/// 取景框顶部信息浮层：宝宝小名 + 当前成长天数（PRD §4.3.2，仅预览，默认不烧入像素）。
final class OverlayView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let nameLabel = UILabel()
    private let ageLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true

        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center

        ageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        ageLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        ageLabel.textAlignment = .center

        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(ageLabel)

        addSubview(blurView)
        blurView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -14),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -8),
        ])

        accessibilityElements = [nameLabel, ageLabel]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(info: CameraOverlayInfo?) {
        guard let info else {
            isHidden = true
            nameLabel.text = nil
            ageLabel.text = nil
            return
        }

        nameLabel.text = info.babyName
        ageLabel.text = info.displayAge
        nameLabel.accessibilityLabel = info.babyName
        ageLabel.accessibilityLabel = info.displayAge
        isHidden = false
        accessibilityLabel = "\(info.babyName)，\(info.displayAge)"
    }
}

/// 三分法网格线叠加层。
final class GridOverlayView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.45).cgColor
        shapeLayer.lineWidth = 0.5
        shapeLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGrid()
    }

    private func updateGrid() {
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height

        let thirdW = width / 3
        let thirdH = height / 3

        for index in 1...2 {
            let x = thirdW * CGFloat(index)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))

            let y = thirdH * CGFloat(index)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }

        shapeLayer.path = path.cgPath
        shapeLayer.frame = bounds
    }
}

/// 水平仪叠加层：根据设备姿态绘制地平线参考线。
@MainActor
final class LevelOverlayView: UIView {
    private let horizonLayer = CAShapeLayer()
    private let motionManager = CMMotionManager()
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        horizonLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.85).cgColor
        horizonLayer.lineWidth = 2
        horizonLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(horizonLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.updateHorizon(roll: motion.attitude.roll)
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redrawHorizon(roll: 0)
    }

    private func updateHorizon(roll: Double) {
        redrawHorizon(roll: roll)
    }

    private func redrawHorizon(roll: Double) {
        let centerY = bounds.midY
        let offset = CGFloat(roll) * bounds.width * 0.25
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: centerY + offset))
        path.addLine(to: CGPoint(x: bounds.width, y: centerY - offset))
        horizonLayer.path = path.cgPath
        horizonLayer.frame = bounds
    }
}

/// 倒计时数字叠加层。
final class CountdownOverlayView: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 96, weight: .bold)
        textColor = .white
        textAlignment = .center
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 8
        isHidden = true
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(seconds: Int) {
        text = "\(seconds)"
        isHidden = false
        isAccessibilityElement = true
        accessibilityLabel = "倒计时 \(seconds) 秒"
        transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        UIView.animate(withDuration: 0.25) {
            self.transform = .identity
        }
    }

    func hide() {
        isHidden = true
        text = nil
        isAccessibilityElement = false
    }
}
