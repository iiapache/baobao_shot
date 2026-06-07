import Foundation

/// 解析评论中的 `@昵称` 并映射到家人 userId。
public enum MentionResolver {
    public static func mentionUserIds(in text: String, candidates: [FeedMentionCandidate]) -> [String] {
        let tokens = extractMentionTokens(from: text)
        guard !tokens.isEmpty else { return [] }

        var resolved: [String] = []
        for token in tokens {
            if let match = candidates.first(where: { $0.nickname == token }) {
                if !resolved.contains(match.id) {
                    resolved.append(match.id)
                }
            }
        }
        return resolved
    }

    public static func insertMention(_ candidate: FeedMentionCandidate, into text: String) -> String {
        let mention = "@\(candidate.nickname) "
        if text.isEmpty {
            return mention
        }
        if text.hasSuffix(" ") {
            return text + mention
        }
        return text + " " + mention
    }

    public static func extractMentionTokens(from text: String) -> [String] {
        let pattern = #"@([^\s@]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let tokenRange = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[tokenRange])
        }
    }
}
