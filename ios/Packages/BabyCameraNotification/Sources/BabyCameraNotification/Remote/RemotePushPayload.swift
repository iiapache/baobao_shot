import BabyCameraNetwork
import Foundation

/// APNs `userInfo` 解析，对齐 notification-svc CustomData + `aps` 字段。
public struct RemotePushPayload: Sendable, Equatable {
    public let category: NotificationCategoryCode
    public let isSilent: Bool
    public let taskId: String?
    public let state: String?
    public let resultUrl: String?
    public let thumbnailUrl: String?
    public let babyId: String?
    public let milestoneId: String?
    public let templateId: String?

    public init(
        category: NotificationCategoryCode,
        isSilent: Bool,
        taskId: String? = nil,
        state: String? = nil,
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil,
        babyId: String? = nil,
        milestoneId: String? = nil,
        templateId: String? = nil
    ) {
        self.category = category
        self.isSilent = isSilent
        self.taskId = taskId
        self.state = state
        self.resultUrl = resultUrl
        self.thumbnailUrl = thumbnailUrl
        self.babyId = babyId
        self.milestoneId = milestoneId
        self.templateId = templateId
    }

    public var isSilentAIDone: Bool {
        isSilent && category == .aiDone && taskId != nil
    }

    public static func from(userInfo: [AnyHashable: Any]) -> RemotePushPayload? {
        guard let category = parseCategory(from: userInfo) else {
            return nil
        }

        let aps = userInfo["aps"] as? [AnyHashable: Any]
        let contentAvailable = parseInt(aps?["content-available"]) == 1
        let hasAlert = aps?["alert"] != nil
        let isSilent = contentAvailable && !hasAlert

        return RemotePushPayload(
            category: category,
            isSilent: isSilent,
            taskId: stringValue(userInfo["taskId"]),
            state: stringValue(userInfo["state"]),
            resultUrl: stringValue(userInfo["resultUrl"]),
            thumbnailUrl: stringValue(userInfo["thumbnailUrl"]),
            babyId: stringValue(userInfo["babyId"]),
            milestoneId: stringValue(userInfo["milestoneId"]),
            templateId: stringValue(userInfo["templateId"])
        )
    }

    // MARK: - Private

    private static func parseCategory(from userInfo: [AnyHashable: Any]) -> NotificationCategoryCode? {
        if let raw = stringValue(userInfo["category"]),
           let code = NotificationCategoryCode(rawValue: raw) {
            return code
        }
        if let aps = userInfo["aps"] as? [AnyHashable: Any],
           let raw = stringValue(aps["category"]),
           let code = NotificationCategoryCode(rawValue: raw) {
            return code
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func parseInt(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }
}
