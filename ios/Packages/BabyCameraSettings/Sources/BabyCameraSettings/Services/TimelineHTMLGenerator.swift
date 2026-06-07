import DesignSystem
import Foundation

/// 生成可在 zip 内离线浏览的时间线 HTML 预览。
public struct TimelineHTMLGenerator: Sendable {
    private let dateFormatter: DateFormatter
    private let locale: Locale
    private let timeZone: TimeZone

    public init(
        locale: Locale = Locale(identifier: "zh_CN"),
        timeZone: TimeZone = .current
    ) {
        self.locale = locale
        self.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        self.dateFormatter = formatter
    }

    public func generate(
        manifest: DataExportManifest,
        photosDirectoryName: String
    ) -> String {
        let grouped = groupPhotos(manifest.photos)
        let babyNames = Dictionary(uniqueKeysWithValues: manifest.babies.map { ($0.id, $0.name) })
        let sections = grouped.map { day, photos in
            renderSection(
                day: day,
                photos: photos,
                babyNames: babyNames,
                photosDirectoryName: photosDirectoryName
            )
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>\(L10n.string("settings.export.html.document_title"))</title>
          <style>
            :root { color-scheme: light; }
            body { font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; margin: 0; background: #f7f4ef; color: #1f1a17; }
            header { padding: 24px 20px 12px; background: #fff8ef; border-bottom: 1px solid #eadfce; }
            h1 { margin: 0 0 8px; font-size: 24px; }
            .meta { color: #6f655c; font-size: 14px; }
            main { padding: 16px 20px 40px; }
            section { margin-bottom: 28px; }
            h2 { font-size: 18px; margin: 0 0 12px; }
            .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 12px; }
            figure { margin: 0; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 16px rgba(31, 26, 23, 0.08); }
            img { width: 100%; aspect-ratio: 1; object-fit: cover; display: block; background: #efe8df; }
            figcaption { padding: 10px 12px; font-size: 12px; line-height: 1.4; color: #4d453d; }
            .badge { display: inline-block; margin-top: 4px; padding: 2px 8px; border-radius: 999px; background: #f0e4d4; color: #6a4d2f; }
          </style>
        </head>
        <body>
          <header>
            <h1>\(L10n.string("settings.export.html.heading"))</h1>
            <p class="meta">\(L10n.string("settings.export.html.meta", manifest.exportedAt, manifest.photos.count))</p>
          </header>
          <main>
        \(sections)
          </main>
        </body>
        </html>
        """
    }

    private func groupPhotos(_ photos: [DataExportPhoto]) -> [(String, [DataExportPhoto])] {
        let sorted = photos.sorted { $0.takenAt > $1.takenAt }
        var buckets: [(String, [DataExportPhoto])] = []
        var currentDay: String?
        var currentPhotos: [DataExportPhoto] = []

        for photo in sorted {
            let day = dayTitle(for: photo.takenAt)
            if currentDay != day {
                if let currentDay, !currentPhotos.isEmpty {
                    buckets.append((currentDay, currentPhotos))
                }
                currentDay = day
                currentPhotos = [photo]
            } else {
                currentPhotos.append(photo)
            }
        }

        if let currentDay, !currentPhotos.isEmpty {
            buckets.append((currentDay, currentPhotos))
        }

        return buckets
    }

    private func renderSection(
        day: String,
        photos: [DataExportPhoto],
        babyNames: [String: String],
        photosDirectoryName: String
    ) -> String {
        let unlabeled = L10n.string("settings.export.html.unlabeled_baby")
        let cards = photos.map { photo in
            let babyLabel = photo.babyIds.compactMap { babyNames[$0] }.joined(separator: "、")
            let takenAt = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(photo.takenAt)))
            let badge = babyLabel.isEmpty ? unlabeled : babyLabel
            return """
                <figure>
                  <img src="\(photosDirectoryName)/\(photo.archivePath)" alt="\(photo.id)" loading="lazy" />
                  <figcaption>
                    \(takenAt)
                    <span class="badge">\(badge)</span>
                  </figcaption>
                </figure>
            """
        }.joined(separator: "\n")

        return """
            <section>
              <h2>\(day)</h2>
              <div class="grid">
            \(cards)
              </div>
            </section>
        """
    }

    private func dayTitle(for takenAt: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(takenAt))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMMd")
        return formatter.string(from: date)
    }
}
