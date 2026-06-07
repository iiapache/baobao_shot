import Foundation

/// 客服反馈日志脱敏（T6.13）：Token / 手机号 / Apple Sub 替换为 `***`。
public enum FeedbackLogRedactor {
    public static let redactedPlaceholder = "***"

    private static let bearerPattern = try! NSRegularExpression(
        pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
        options: [.caseInsensitive]
    )
    private static let accessTokenPattern = try! NSRegularExpression(
        pattern: #"("accessToken"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let refreshTokenPattern = try! NSRegularExpression(
        pattern: #"("refreshToken"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let phoneFieldPattern = try! NSRegularExpression(
        pattern: #"("phone"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let appleSubFieldPattern = try! NSRegularExpression(
        pattern: #"("appleSub"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let phonePattern = try! NSRegularExpression(
        pattern: #"(?<!\d)(1[3-9]\d{9})(?!\d)"#,
        options: []
    )

    public static func redact(_ input: String) -> String {
        var result = input
        result = replaceMatches(
            in: result,
            pattern: bearerPattern,
            template: "Bearer \(redactedPlaceholder)"
        )
        result = replaceMatches(
            in: result,
            pattern: accessTokenPattern,
            template: "$1\(redactedPlaceholder)$2"
        )
        result = replaceMatches(
            in: result,
            pattern: refreshTokenPattern,
            template: "$1\(redactedPlaceholder)$2"
        )
        result = replaceMatches(
            in: result,
            pattern: phoneFieldPattern,
            template: "$1\(redactedPlaceholder)$2"
        )
        result = replaceMatches(
            in: result,
            pattern: appleSubFieldPattern,
            template: "$1\(redactedPlaceholder)$2"
        )
        result = replaceMatches(
            in: result,
            pattern: phonePattern,
            template: redactedPlaceholder
        )
        return result
    }

    private static func replaceMatches(
        in input: String,
        pattern: NSRegularExpression,
        template: String
    ) -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return pattern.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
}
