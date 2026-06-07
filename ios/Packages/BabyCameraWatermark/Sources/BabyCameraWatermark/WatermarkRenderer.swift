import BabyCameraImageKit
import CoreGraphics
import CoreImage
import Foundation
import UIKit

/// 水印渲染选项。
public struct WatermarkRenderOptions: Sendable, Equatable {
    /// 是否合成深度合成强制角标（AI 出参 / 分享链路开启，普通相机拍照默认关闭）。
    public var includeDeepSynthesisBadge: Bool

    public init(includeDeepSynthesisBadge: Bool = false) {
        self.includeDeepSynthesisBadge = includeDeepSynthesisBadge
    }

    public static let cameraCapture = WatermarkRenderOptions(includeDeepSynthesisBadge: false)
    public static let aiResult = WatermarkRenderOptions(includeDeepSynthesisBadge: true)
}

/// 水印渲染协议，便于单测注入 mock。
public protocol WatermarkRendering: Sendable {
    func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool
    func compositeBrandWatermark(onto image: CIImage, isSubscribed: Bool) -> CIImage
    func compositeDeepSynthesisBadge(onto image: CIImage) -> CIImage
    func compositeAllWatermarks(
        onto image: CIImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions
    ) -> CIImage
    func drawBrandWatermark(on image: CGImage) throws -> CGImage
    func drawDeepSynthesisBadge(on image: CGImage) throws -> CGImage
    func drawAllWatermarks(
        on image: CGImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions
    ) throws -> CGImage
    func render(
        sourceFileURL: URL,
        format: ImageFormat,
        isSubscribed: Bool,
        destinationURL: URL,
        options: WatermarkRenderOptions
    ) throws -> URL
}

/// 品牌水印 + 深度合成角标合成器：CoreGraphics 落盘 + CIImage 链式合成。
public final class WatermarkRenderer: WatermarkRendering, @unchecked Sendable {
    private let policy: any BrandWatermarkPolicy
    private let codec: any ImageCodecProtocol
    private let context: CIContext

    public init(
        policy: any BrandWatermarkPolicy = SubscriptionBrandWatermarkPolicy(),
        codec: any ImageCodecProtocol = ImageCodec(),
        context: CIContext? = nil
    ) {
        self.policy = policy
        self.codec = codec
        self.context = context ?? CIContext(options: [.useSoftwareRenderer: true])
    }

    public func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool {
        policy.shouldShowBrandWatermark(isSubscribed: isSubscribed)
    }

    public func compositeBrandWatermark(onto image: CIImage, isSubscribed: Bool) -> CIImage {
        guard shouldShowBrandWatermark(isSubscribed: isSubscribed) else {
            return image
        }

        let extent = image.extent
        guard let overlay = makeBrandWatermarkOverlay(canvasSize: extent.size) else {
            return image
        }

        let margin = BrandWatermarkLayout.margin(for: extent.size)
        let positioned = overlay.transformed(
            by: CGAffineTransform(translationX: extent.minX + margin, y: extent.minY + margin)
        )
        return positioned.composited(over: image)
    }

    public func compositeDeepSynthesisBadge(onto image: CIImage) -> CIImage {
        let extent = image.extent
        let backgroundRect = DeepSynthesisBadgeLayout.backgroundRect(canvasSize: extent.size)
        guard let overlay = makeDeepSynthesisBadgeOverlay(badgeSize: backgroundRect.size) else {
            return image
        }

        let margin = DeepSynthesisBadgeLayout.margin(for: extent.size)
        let positioned = overlay.transformed(
            by: CGAffineTransform(
                translationX: extent.minX + backgroundRect.minX,
                y: extent.minY + margin
            )
        )
        return positioned.composited(over: image)
    }

    public func compositeAllWatermarks(
        onto image: CIImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions = .cameraCapture
    ) -> CIImage {
        let base = options.includeDeepSynthesisBadge
            ? compositeDeepSynthesisBadge(onto: image)
            : image
        return compositeBrandWatermark(onto: base, isSubscribed: isSubscribed)
    }

    public func drawBrandWatermark(on image: CGImage) throws -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = makeContext(width: width, height: height, colorSpace: colorSpace, bitmapInfo: bitmapInfo) else {
            throw WatermarkError.renderFailed
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        drawBrandText(in: ctx, canvasSize: CGSize(width: width, height: height))
        guard let output = ctx.makeImage() else {
            throw WatermarkError.renderFailed
        }
        return output
    }

    public func drawDeepSynthesisBadge(on image: CGImage) throws -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = makeContext(width: width, height: height, colorSpace: colorSpace, bitmapInfo: bitmapInfo) else {
            throw WatermarkError.renderFailed
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        drawDeepSynthesisBadge(in: ctx, canvasSize: CGSize(width: width, height: height))
        guard let output = ctx.makeImage() else {
            throw WatermarkError.renderFailed
        }
        return output
    }

    public func drawAllWatermarks(
        on image: CGImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions = .cameraCapture
    ) throws -> CGImage {
        var output = image
        if options.includeDeepSynthesisBadge {
            output = try drawDeepSynthesisBadge(on: output)
        }
        if shouldShowBrandWatermark(isSubscribed: isSubscribed) {
            output = try drawBrandWatermark(on: output)
        }
        return output
    }

    public func render(
        sourceFileURL: URL,
        format: ImageFormat,
        isSubscribed: Bool,
        destinationURL: URL,
        options: WatermarkRenderOptions = .cameraCapture
    ) throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceFileURL.path) else {
            throw WatermarkError.sourceFileUnreadable
        }

        let data = try Data(contentsOf: sourceFileURL)
        let sourceImage = try codec.decode(data: data)
        let outputImage = try drawAllWatermarks(on: sourceImage, isSubscribed: isSubscribed, options: options)

        let encoded = try codec.encode(image: outputImage, format: format)
        let directory = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try encoded.data.write(to: destinationURL, options: .atomic)
        } catch {
            throw WatermarkError.writeFailed
        }
        return destinationURL
    }

    private func makeContext(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace,
        bitmapInfo: UInt32
    ) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    private func makeBrandWatermarkOverlay(canvasSize: CGSize) -> CIImage? {
        let fontSize = BrandWatermarkLayout.fontSize(for: canvasSize)
        let textSize = BrandWatermarkLayout.measuredTextSize(fontSize: fontSize)
        let overlaySize = CGSize(
            width: textSize.width + fontSize * 0.4,
            height: textSize.height + fontSize * 0.3
        )

        let renderer = UIGraphicsImageRenderer(size: overlaySize)
        let uiImage = renderer.image { ctx in
            let cgContext = ctx.cgContext
            cgContext.setFillColor(UIColor.clear.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: overlaySize))
            drawBrandText(in: cgContext, canvasSize: overlaySize)
        }
        return CIImage(image: uiImage)
    }

    private func makeDeepSynthesisBadgeOverlay(badgeSize: CGSize) -> CIImage? {
        let renderer = UIGraphicsImageRenderer(size: badgeSize)
        let uiImage = renderer.image { ctx in
            let cgContext = ctx.cgContext
            cgContext.setFillColor(UIColor.clear.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: badgeSize))
            drawDeepSynthesisBadgeLocal(in: cgContext, badgeSize: badgeSize)
        }
        return CIImage(image: uiImage)
    }

    private func drawBrandText(in context: CGContext, canvasSize: CGSize) {
        let fontSize = BrandWatermarkLayout.fontSize(for: canvasSize)
        let origin = BrandWatermarkLayout.textOrigin(canvasSize: canvasSize)
        let attributes = BrandWatermarkTextStyle.attributes(fontSize: fontSize)
        (BrandWatermarkLayout.brandText as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func drawDeepSynthesisBadge(in context: CGContext, canvasSize: CGSize) {
        let backgroundRect = DeepSynthesisBadgeLayout.backgroundRect(canvasSize: canvasSize)
        drawDeepSynthesisBadgeLocal(in: context, badgeSize: backgroundRect.size, offset: backgroundRect.origin)
    }

    private func drawDeepSynthesisBadgeLocal(
        in context: CGContext,
        badgeSize: CGSize,
        offset: CGPoint = .zero
    ) {
        let backgroundRect = CGRect(origin: offset, size: badgeSize)
        let cornerRadius = backgroundRect.height * 0.18
        context.setFillColor(UIColor.black.withAlphaComponent(DeepSynthesisBadgeLayout.backgroundOpacity).cgColor)
        context.addPath(CGPath(
            roundedRect: backgroundRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        ))
        context.fillPath()

        let fontSize = badgeSize.height * 0.42
        let textSize = DeepSynthesisBadgeLayout.measuredTextSize(fontSize: fontSize)
        let origin = CGPoint(
            x: offset.x + (badgeSize.width - textSize.width) / 2,
            y: offset.y + (badgeSize.height - textSize.height) / 2
        )
        let attributes = DeepSynthesisBadgeTextStyle.attributes(fontSize: fontSize)
        (DeepSynthesisBadgeLayout.badgeText as NSString).draw(at: origin, withAttributes: attributes)
    }
}
