import Foundation

public struct MilestoneNotificationPayload: Sendable, Equatable {
    public static let deepLinkScheme = "baobao"
    public static let deepLinkHost = "milestone"

    public static let babyIdKey = "babyId"
    public static let milestoneIdKey = "milestoneId"
    public static let templateIdKey = "templateId"
    public static let deepLinkKey = "deepLink"

    public var babyId: String
    public var milestoneId: String
    public var templateId: String?

    public init(babyId: String, milestoneId: String, templateId: String? = nil) {
        self.babyId = babyId
        self.milestoneId = milestoneId
        self.templateId = templateId
    }

    public var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = Self.deepLinkScheme
        components.host = Self.deepLinkHost
        var queryItems = [
            URLQueryItem(name: Self.babyIdKey, value: babyId),
            URLQueryItem(name: Self.milestoneIdKey, value: milestoneId),
        ]
        if let templateId {
            queryItems.append(URLQueryItem(name: Self.templateIdKey, value: templateId))
        }
        components.queryItems = queryItems
        return components.url
    }

    public static func userInfo(
        babyId: String,
        milestoneId: String,
        templateId: String?,
        triggerDate: Date
    ) -> [AnyHashable: Any] {
        let payload = MilestoneNotificationPayload(
            babyId: babyId,
            milestoneId: milestoneId,
            templateId: templateId
        )
        var info: [AnyHashable: Any] = [
            babyIdKey: babyId,
            milestoneIdKey: milestoneId,
            "triggerDate": Int64(triggerDate.timeIntervalSince1970),
        ]
        if let templateId {
            info[templateIdKey] = templateId
        }
        if let deepLink = payload.deepLinkURL?.absoluteString {
            info[deepLinkKey] = deepLink
        }
        return info
    }

    public static func from(userInfo: [AnyHashable: Any]) -> MilestoneNotificationPayload? {
        guard let babyId = userInfo[babyIdKey] as? String,
              let milestoneId = userInfo[milestoneIdKey] as? String else {
            return nil
        }
        let templateId = userInfo[templateIdKey] as? String
        return MilestoneNotificationPayload(
            babyId: babyId,
            milestoneId: milestoneId,
            templateId: templateId
        )
    }

    public static func from(deepLink url: URL) -> MilestoneNotificationPayload? {
        guard url.scheme == deepLinkScheme, url.host == deepLinkHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let queryItems = components.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }
        guard let babyId = value(babyIdKey), let milestoneId = value(milestoneIdKey) else {
            return nil
        }
        return MilestoneNotificationPayload(
            babyId: babyId,
            milestoneId: milestoneId,
            templateId: value(templateIdKey)
        )
    }
}
