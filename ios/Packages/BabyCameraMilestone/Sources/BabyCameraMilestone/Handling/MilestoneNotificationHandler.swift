import BabyCameraEditor
import Foundation
import UserNotifications

/// 里程碑通知点击后的 deep link 解析与编辑器模板入口（design-ios §10.1 MILESTONE category）。
public enum MilestoneNotificationHandler {
    public struct Destination: Sendable, Equatable {
        public var babyId: String
        public var milestoneId: String
        public var milestoneName: String
        public var templateId: String?
        public var templateStep: TemplateStep?

        public init(
            babyId: String,
            milestoneId: String,
            milestoneName: String,
            templateId: String? = nil,
            templateStep: TemplateStep? = nil
        ) {
            self.babyId = babyId
            self.milestoneId = milestoneId
            self.milestoneName = milestoneName
            self.templateId = templateId
            self.templateStep = templateStep
        }
    }

    public enum Error: Swift.Error, Equatable {
        case invalidPayload
        case templateNotFound(String)
        case templateBuildFailed(String)
    }

    /// 从通知 `userInfo` 解析目标路由。
    public static func destination(from userInfo: [AnyHashable: Any]) throws -> Destination {
        guard let payload = MilestoneNotificationPayload.from(userInfo: userInfo) else {
            throw Error.invalidPayload
        }
        return try resolveDestination(from: payload)
    }

    /// 从 deep link URL 解析目标路由。
    public static func destination(from url: URL) throws -> Destination {
        guard let payload = MilestoneNotificationPayload.from(deepLink: url) else {
            throw Error.invalidPayload
        }
        return try resolveDestination(from: payload)
    }

    /// 从 `UNNotificationResponse` 解析目标路由（通知 action / 默认点击）。
    public static func destination(from response: UNNotificationResponse) throws -> Destination {
        let userInfo = response.notification.request.content.userInfo
        return try destination(from: userInfo)
    }

    /// 构建带占位符的 `TemplateStep`，供编辑器直接加载。
    public static func makeTemplateStep(
        templateId: String,
        placeholders: [TemplatePlaceholder] = []
    ) throws -> TemplateStep {
        guard TemplateCatalog.template(for: templateId) != nil else {
            throw Error.templateNotFound(templateId)
        }
        do {
            return try TemplateCatalog.makeTemplateStep(templateID: templateId, placeholders: placeholders)
        } catch {
            throw Error.templateBuildFailed(templateId)
        }
    }

    // MARK: - Private

    private static func resolveDestination(from payload: MilestoneNotificationPayload) throws -> Destination {
        let milestone = MilestoneCatalog.milestone(for: payload.milestoneId)
        let resolvedTemplateId = payload.templateId ?? milestone?.templateId

        var templateStep: TemplateStep?
        if let templateId = resolvedTemplateId {
            templateStep = try? makeTemplateStep(templateId: templateId)
        }

        return Destination(
            babyId: payload.babyId,
            milestoneId: payload.milestoneId,
            milestoneName: milestone?.name ?? payload.milestoneId,
            templateId: resolvedTemplateId,
            templateStep: templateStep
        )
    }
}
