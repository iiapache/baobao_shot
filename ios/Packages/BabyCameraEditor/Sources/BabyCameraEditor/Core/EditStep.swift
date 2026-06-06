import CoreImage
import Foundation

/// 单步编辑操作：可重放、可序列化。
public protocol EditStep: Codable, Equatable, Sendable {
    var kind: EditStepKind { get }
    func apply(to image: CIImage) -> CIImage
}
