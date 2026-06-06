import AVFoundation
import CoreGraphics
import Foundation

/// 测试用 H.264 MP4 视频生成器。
enum TestVideoFactory {
    enum Color {
        case red, green, blue
    }

    static func makeH264MP4(
        width: Int = 640,
        height: Int = 480,
        duration: TimeInterval = 1.0,
        fps: Int32 = 30,
        color: Color = .red
    ) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-video-\(UUID().uuidString).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw TestVideoFactoryError.cannotAddVideoInput
        }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw TestVideoFactoryError.startWritingFailed
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(duration * Double(fps)))
        let frameDuration = CMTime(value: 1, timescale: fps)

        for frameIndex in 0 ..< frameCount {
            while !videoInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            guard let pixelBuffer = makePixelBuffer(
                width: width,
                height: height,
                color: color,
                frameIndex: frameIndex
            ) else {
                throw TestVideoFactoryError.pixelBufferCreationFailed
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw TestVideoFactoryError.appendFrameFailed
            }
        }

        videoInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw TestVideoFactoryError.finishWritingFailed
        }

        return outputURL
    }

    // MARK: - Private

    private static func makePixelBuffer(
        width: Int,
        height: Int,
        color: Color,
        frameIndex: Int
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let offset = (frameIndex % 3) * 40
        let (r, g, b): (UInt8, UInt8, UInt8)
        switch color {
        case .red: (r, g, b) = (255, UInt8(offset), 0)
        case .green: (r, g, b) = (0, 255, UInt8(offset))
        case .blue: (r, g, b) = (0, UInt8(offset), 255)
        }

        for y in 0 ..< height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0 ..< width {
                let index = x * 4
                row[index] = 255
                row[index + 1] = r
                row[index + 2] = g
                row[index + 3] = b
            }
        }

        return buffer
    }

}

enum TestVideoFactoryError: Error {
    case cannotAddVideoInput
    case startWritingFailed
    case pixelBufferCreationFailed
    case appendFrameFailed
    case finishWritingFailed
}
