import BabyCameraNetwork
import Foundation
import UIKit

public struct ShareActivityPresentation: Equatable, Sendable {
    public let fileURLs: [URL]
    public let texts: [String]

    public init(fileURLs: [URL], texts: [String] = []) {
        self.fileURLs = fileURLs
        self.texts = texts
    }

    var activityItems: [Any] {
        fileURLs.map { $0 as NSURL } + texts
    }
}

public struct SystemShareOutcome: Equatable, Sendable {
    public let preparedAsset: SharePreparedAsset
    public let clipboardResult: ClipboardWriteResult
    public let destination: ShareDestination
    public let presentation: ShareActivityPresentation

    public init(
        preparedAsset: SharePreparedAsset,
        clipboardResult: ClipboardWriteResult,
        destination: ShareDestination,
        presentation: ShareActivityPresentation
    ) {
        self.preparedAsset = preparedAsset
        self.clipboardResult = clipboardResult
        self.destination = destination
        self.presentation = presentation
    }
}

public enum SystemShareError: Error, Equatable, Sendable {
    case preparationFailed(SharePreparerError)
}

@MainActor
public protocol ShareActivityPresenting: AnyObject {
    func present(
        _ presentation: ShareActivityPresentation,
        from viewController: UIViewController
    )
}

@MainActor
public final class LiveShareActivityPresenter: ShareActivityPresenting {
    public init() {}

    public func present(
        _ presentation: ShareActivityPresentation,
        from viewController: UIViewController
    ) {
        let controller = UIActivityViewController(
            activityItems: presentation.activityItems,
            applicationActivities: nil
        )

        if let popover = controller.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(controller, animated: true)
    }
}

@MainActor
public protocol SystemShareAdapting {
    func share(
        _ request: SystemShareRequest,
        from viewController: UIViewController
    ) async throws -> SystemShareOutcome
}

/// 系统分享适配器（T5.14）：SharePreparer 水印 → 剪贴板智能文案 → `UIActivityViewController`。
@MainActor
public final class SystemShareAdapter: SystemShareAdapting {
    private let preparer: any SharePreparing
    private let clipboardWriter: ClipboardWriter
    private let activityPresenter: any ShareActivityPresenting

    public init(
        preparer: any SharePreparing = SharePreparer(),
        clipboardWriter: ClipboardWriter = ClipboardWriter(),
        activityPresenter: any ShareActivityPresenting = LiveShareActivityPresenter()
    ) {
        self.preparer = preparer
        self.clipboardWriter = clipboardWriter
        self.activityPresenter = activityPresenter
    }

    public func share(
        _ request: SystemShareRequest,
        from viewController: UIViewController
    ) async throws -> SystemShareOutcome {
        let preparedAsset: SharePreparedAsset
        do {
            preparedAsset = try await preparer.prepare(request.preparationRequest)
        } catch let error as SharePreparerError {
            throw SystemShareError.preparationFailed(error)
        }

        let captionText = request.caption?.composedText ?? request.fallbackCaption
        let clipboardResult = clipboardWriter.writeSmartCaption(
            text: captionText,
            destination: request.destination
        )

        let presentation = ShareActivityPresentation(fileURLs: [preparedAsset.mediaURL])
        activityPresenter.present(presentation, from: viewController)

        return SystemShareOutcome(
            preparedAsset: preparedAsset,
            clipboardResult: clipboardResult,
            destination: request.destination,
            presentation: presentation
        )
    }
}
