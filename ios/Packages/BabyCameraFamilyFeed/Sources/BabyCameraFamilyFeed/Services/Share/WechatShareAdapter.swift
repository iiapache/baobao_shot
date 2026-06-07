import Foundation

public enum WechatShareError: Error, Equatable, Sendable {
    case wechatNotInstalled
    case invalidUniversalLink(String)
    case thumbnailAdaptationFailed
    case mediaReadFailed
    case sendFailed(String)
}

public struct WechatShareConfiguration: Sendable, Equatable {
    public let appID: String
    public let universalLink: String

    public init(appID: String, universalLink: String) {
        self.appID = appID
        self.universalLink = universalLink
    }

    /// 与微信开放平台登记一致的占位；宿主 App 通过 xcconfig → Info.plist 注入产线值。
    public static let `default` = WechatShareConfiguration(
        appID: "wx0000000000000000",
        universalLink: "https://app.babycamera.cn/wechat/"
    )
}

public protocol WechatSharing: Sendable {
    func share(_ request: WechatShareRequest) async throws
}

/// 微信 OpenSDK 分享适配：朋友圈 / 好友，自动文案 + 缩略图压缩（T5.13）。
public struct WechatShareAdapter: WechatSharing {
    private let bridge: any WechatOpenSDKBridging
    private let thumbnailAdapter: WechatThumbnailAdapter
    private let configuration: WechatShareConfiguration
    private let fileManager: FileManager

    public init(
        bridge: any WechatOpenSDKBridging = StubWechatOpenSDKBridge(),
        thumbnailAdapter: WechatThumbnailAdapter = WechatThumbnailAdapter(),
        configuration: WechatShareConfiguration = .default,
        fileManager: FileManager = .default
    ) {
        self.bridge = bridge
        self.thumbnailAdapter = thumbnailAdapter
        self.configuration = configuration
        self.fileManager = fileManager
    }

    public func share(_ request: WechatShareRequest) async throws {
        guard WechatUniversalLinkValidator.validate(configuration.universalLink) else {
            throw WechatShareError.invalidUniversalLink(configuration.universalLink)
        }

        guard bridge.isWechatInstalled else {
            throw WechatShareError.wechatNotInstalled
        }

        guard fileManager.fileExists(atPath: request.asset.mediaURL.path) else {
            throw WechatShareError.mediaReadFailed
        }

        let thumbData: Data
        do {
            thumbData = try thumbnailAdapter.makeThumbData(from: request.asset)
        } catch let error as WechatShareError {
            throw error
        } catch {
            throw WechatShareError.thumbnailAdaptationFailed
        }

        let payload = WechatSharePayload(
            scene: request.scene,
            title: WechatCaptionFormatter.title(from: request.caption, scene: request.scene),
            description: WechatCaptionFormatter.description(from: request.caption, scene: request.scene),
            mediaURL: request.asset.mediaURL,
            mediaKind: request.asset.mediaKind,
            thumbData: thumbData,
            universalLink: configuration.universalLink
        )

        do {
            try await bridge.send(payload)
        } catch let error as WechatShareError {
            throw error
        } catch {
            throw WechatShareError.sendFailed(String(describing: error))
        }
    }
}

enum WechatCaptionFormatter {
    static func title(from caption: String, scene: WechatShareScene) -> String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        switch scene {
        case .timeline:
            return trimmed
        case .session:
            if let firstLine = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first {
                return String(firstLine.prefix(100))
            }
            return String(trimmed.prefix(100))
        }
    }

    static func description(from caption: String, scene: WechatShareScene) -> String {
        switch scene {
        case .timeline:
            return ""
        case .session:
            return caption.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
