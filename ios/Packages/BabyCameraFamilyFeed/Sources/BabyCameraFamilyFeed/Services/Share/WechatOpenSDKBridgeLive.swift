#if canImport(WechatOpenSDK)
import Foundation
import WechatOpenSDK

/// 微信 OpenSDK 真机桥接（INT-05）；仅在链接 WechatOpenSDK 且 `WechatUseOpenSDK=YES` 时由工厂选用。
final class WechatOpenSDKBridgeLive: NSObject, WechatOpenSDKBridging, WXApiDelegate, @unchecked Sendable {
    static let shared = WechatOpenSDKBridgeLive()

    private let lock = NSLock()
    private var pendingContinuation: CheckedContinuation<Void, Error>?

    var isWechatInstalled: Bool {
        WXApi.isWXAppInstalled()
    }

    func send(_ payload: WechatSharePayload) async throws {
        let message = try makeMediaMessage(from: payload)
        let request = SendMessageToWXReq()
        request.message = message
        request.scene = sceneValue(for: payload.scene)

        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingContinuation = continuation
            lock.unlock()

            let dispatched = WXApi.send(request)
            if !dispatched {
                finishPending(with: .failure(WechatShareError.sendFailed("WXApi.send returned false")))
            }
        }
    }

    func handleResponse(_ response: BaseResp) {
        guard response is SendMessageToWXResp else {
            return
        }

        if response.errCode == WXSuccess {
            finishPending(with: .success(()))
            return
        }

        if response.errCode == WXErrCodeUserCancel {
            finishPending(with: .failure(WechatShareError.sendFailed("user_cancelled")))
            return
        }

        let detail = response.errStr.isEmpty ? "errCode=\(response.errCode)" : response.errStr
        finishPending(with: .failure(WechatShareError.sendFailed(detail)))
    }

    // MARK: - WXApiDelegate

    func onResp(_ resp: BaseResp!) {
        handleResponse(resp)
    }

    // MARK: - Private

    private func makeMediaMessage(from payload: WechatSharePayload) throws -> WXMediaMessage {
        let message = WXMediaMessage()
        message.title = payload.title
        message.description = payload.description
        message.thumbData = payload.thumbData

        switch payload.mediaKind {
        case .image:
            let imageObject = WXImageObject()
            imageObject.imageData = try Data(contentsOf: payload.mediaURL)
            message.mediaObject = imageObject
        case .video:
            let videoObject = WXVideoObject()
            let videoData = try Data(contentsOf: payload.mediaURL)
            if videoData.count <= 10 * 1024 * 1024 {
                videoObject.videoData = videoData
            } else {
                videoObject.videoUrl = payload.mediaURL.absoluteString
            }
            message.mediaObject = videoObject
        }

        return message
    }

    private func sceneValue(for scene: WechatShareScene) -> Int32 {
        switch scene {
        case .timeline:
            return Int32(WXSceneTimeline.rawValue)
        case .session:
            return Int32(WXSceneSession.rawValue)
        }
    }

    private func finishPending(with result: Result<Void, Error>) {
        lock.lock()
        let continuation = pendingContinuation
        pendingContinuation = nil
        lock.unlock()

        guard let continuation else { return }
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
#endif
