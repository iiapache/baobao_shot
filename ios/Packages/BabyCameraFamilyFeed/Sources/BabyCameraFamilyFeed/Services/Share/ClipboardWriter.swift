import BabyCameraNetwork
import Foundation
import UIKit

public struct ClipboardWriteResult: Equatable, Sendable {
    public let composedText: String
    public let hintMessage: String

    public init(composedText: String, hintMessage: String) {
        self.composedText = composedText
        self.hintMessage = hintMessage
    }
}

public protocol PasteboardWriting: Sendable {
    func setString(_ value: String)
    func string() -> String?
}

public struct SystemPasteboard: PasteboardWriting {
    public init() {}

    public func setString(_ value: String) {
        UIPasteboard.general.string = value
    }

    public func string() -> String? {
        UIPasteboard.general.string
    }
}

/// 将智能文案（正文 + 话题词）写入剪贴板（T5.14）。
public struct ClipboardWriter: Sendable {
    private let pasteboard: any PasteboardWriting

    public init(pasteboard: any PasteboardWriting = SystemPasteboard()) {
        self.pasteboard = pasteboard
    }

    public func writeSmartCaption(
        _ caption: CaptionCandidate,
        destination: ShareDestination
    ) -> ClipboardWriteResult {
        write(composedText: caption.composedText, destination: destination)
    }

    public func writeSmartCaption(
        text: String,
        destination: ShareDestination
    ) -> ClipboardWriteResult {
        write(composedText: text, destination: destination)
    }

    private func write(
        composedText: String,
        destination: ShareDestination
    ) -> ClipboardWriteResult {
        pasteboard.setString(composedText)
        return ClipboardWriteResult(
            composedText: composedText,
            hintMessage: destination.clipboardHintMessage
        )
    }
}
