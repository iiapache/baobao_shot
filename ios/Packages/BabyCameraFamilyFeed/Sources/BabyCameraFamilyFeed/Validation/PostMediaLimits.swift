import BabyCameraNetwork
import Foundation

/// 家庭圈发布媒体数量上限（design-api §7 / T5.10）。
public enum PostMediaLimits {
    public static let maxImages = 9
    public static let maxVideos = 1

    public static func imageCount(in items: [PostComposerMediaItem]) -> Int {
        items.filter { $0.kind == .image }.count
    }

    public static func videoCount(in items: [PostComposerMediaItem]) -> Int {
        items.filter { $0.kind == .video }.count
    }

    public static func canAddImage(currentItems: [PostComposerMediaItem]) -> Bool {
        imageCount(in: currentItems) < maxImages
    }

    public static func canAddVideo(currentItems: [PostComposerMediaItem]) -> Bool {
        videoCount(in: currentItems) < maxVideos
    }

    public static func remainingImageSlots(in items: [PostComposerMediaItem]) -> Int {
        max(0, maxImages - imageCount(in: items))
    }

    public static func remainingVideoSlots(in items: [PostComposerMediaItem]) -> Int {
        max(0, maxVideos - videoCount(in: items))
    }
}
