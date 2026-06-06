import Foundation
import GRDB

enum JSONStringArrayError: Error {
    case encodingFailed
    case decodingFailed
}

/// Encodes `[String]` as JSON text for SQLite TEXT columns (e.g. `photo.babyIds`).
enum JSONStringArray {
    static func encode(_ values: [String]) throws -> String {
        let data = try JSONEncoder().encode(values)
        guard let text = String(data: data, encoding: .utf8) else {
            throw JSONStringArrayError.encodingFailed
        }
        return text
    }

    static func decode(_ text: String) throws -> [String] {
        guard let data = text.data(using: .utf8) else {
            throw JSONStringArrayError.decodingFailed
        }
        return try JSONDecoder().decode([String].self, from: data)
    }
}
