import CoreImage
import Foundation

/// 模板占位符键值。
public struct TemplatePlaceholder: Codable, Equatable, Sendable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// 模板步骤：预设步骤序列 + 占位符；manifest 由 `TemplateCatalog` 构建。
public struct TemplateStep: EditStep {
    public var kind: EditStepKind { .template }

    public var templateID: String
    public var placeholders: [TemplatePlaceholder]
    public var nestedSteps: [AnyEditStep]

    public init(templateID: String, placeholders: [TemplatePlaceholder] = [], nestedSteps: [AnyEditStep] = []) {
        self.templateID = templateID
        self.placeholders = placeholders
        self.nestedSteps = nestedSteps
    }

    public func apply(to image: CIImage) -> CIImage {
        nestedSteps.reduce(image) { current, step in
            step.apply(to: current)
        }
    }
}
