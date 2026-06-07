import CoreGraphics
import CoreImage
import Darwin
import Foundation

/// 分块离屏渲染：大图按 `TileLayout` 逐块写入 mmap 缓冲，控制峰值内存。
public struct TileRenderer: Sendable {
    private let context: CIContextRendering
    private let configuration: EditorRenderConfiguration
    private let colorSpace: CGColorSpace

    public init(
        context: CIContextRendering,
        configuration: EditorRenderConfiguration = .default,
        colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    ) {
        self.context = context
        self.configuration = configuration
        self.colorSpace = colorSpace
    }

    public func renderToCGImage(_ image: CIImage) throws -> CGImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw EditorRenderError.invalidExtent
        }

        let layout = TileLayout.compute(
            outputWidth: Int(extent.width.rounded(.down)),
            outputHeight: Int(extent.height.rounded(.down)),
            configuration: configuration
        )

        let outputExtent = CGRect(
            x: extent.origin.x,
            y: extent.origin.y,
            width: CGFloat(layout.outputWidth),
            height: CGFloat(layout.outputHeight)
        )
        let outputImage = image.cropped(to: outputExtent)

        if layout.tileCount == 1 {
            return try renderSingleTile(outputImage, layout: layout, origin: outputExtent.origin)
        }

        return try renderTiled(outputImage, layout: layout, origin: outputExtent.origin)
    }

    // MARK: - Private

    private func renderSingleTile(
        _ image: CIImage,
        layout: TileLayout,
        origin: CGPoint
    ) throws -> CGImage {
        let rect = CGRect(
            x: origin.x,
            y: origin.y,
            width: CGFloat(layout.outputWidth),
            height: CGFloat(layout.outputHeight)
        )
        guard let cgImage = context.createCGImage(
            image,
            from: rect,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            throw EditorRenderError.renderFailed
        }
        return cgImage
    }

    private func renderTiled(
        _ image: CIImage,
        layout: TileLayout,
        origin: CGPoint
    ) throws -> CGImage {
        let width = layout.outputWidth
        let height = layout.outputHeight
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height

        let storage = try MmapBitmapStorage(byteCount: totalBytes)
        defer { storage.close() }

        for row in 0..<layout.rowCount {
            for column in 0..<layout.columnCount {
                let tileRect = layout.tileRect(column: column, row: row)
                let sourceRect = CGRect(
                    x: origin.x + tileRect.origin.x,
                    y: origin.y + tileRect.origin.y,
                    width: tileRect.width,
                    height: tileRect.height
                )

                let destinationOffset = Int(tileRect.origin.y) * bytesPerRow + Int(tileRect.origin.x) * 4
                let destination = storage.pointer.advanced(by: destinationOffset)

                context.render(
                    image,
                    toBitmap: destination,
                    rowBytes: bytesPerRow,
                    bounds: sourceRect,
                    format: .RGBA8,
                    colorSpace: colorSpace
                )
            }
        }

        guard let provider = CGDataProvider(
            dataInfo: Unmanaged.passRetained(storage).toOpaque(),
            getBytes: { info, buffer, offset, count in
                let storage = Unmanaged<MmapBitmapStorage>.fromOpaque(info!).takeUnretainedValue()
                memcpy(buffer, storage.pointer.advanced(by: offset), count)
                return count
            },
            releaseData: { info in
                _ = Unmanaged<MmapBitmapStorage>.fromOpaque(info!).takeRetainedValue()
            }
        ) else {
            throw EditorRenderError.renderFailed
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw EditorRenderError.renderFailed
        }

        // Provider 已 retain storage；避免 defer 重复释放。
        storage.clearOwnership()
        return cgImage
    }
}

// MARK: - mmap backing store

final class MmapBitmapStorage {
    private(set) var pointer: UnsafeMutableRawPointer
    private var byteCount: Int
    private var fileDescriptor: Int32
    private var temporaryURL: URL?
    private var ownsResources = true

    init(byteCount: Int) throws {
        self.byteCount = byteCount
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-render-\(UUID().uuidString)", isDirectory: false)
        self.temporaryURL = tempURL

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fd = open(tempURL.path, O_RDWR)
        guard fd >= 0 else {
            throw EditorRenderError.mmapFailed
        }
        self.fileDescriptor = fd

        guard ftruncate(fd, off_t(byteCount)) == 0 else {
            Darwin.close(fd)
            throw EditorRenderError.mmapFailed
        }

        let mapped = mmap(nil, byteCount, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard mapped != MAP_FAILED else {
            Darwin.close(fd)
            throw EditorRenderError.mmapFailed
        }
        self.pointer = mapped
    }

    func clearOwnership() {
        ownsResources = false
    }

    func close() {
        guard ownsResources else { return }
        munmap(pointer, byteCount)
        Darwin.close(fileDescriptor)
        if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        ownsResources = false
    }

    deinit {
        close()
    }
}
