import Foundation

#if canImport(UIKit)
import CoreText
import UIKit
#endif

/// 编辑器字体库（T2.13：≥ 6 款，对接 design-assets/fonts/manifest.json，授权与 T0.11 对齐）。
public enum FontCatalog {
    public static let minimumFontCount = 6
    public static let manifestResourceName = "fonts-manifest"
    public static let defaultFontID = "font_baobao_rounded"

    private static let manifest: FontManifest = {
        do {
            return try DesignAssetManifestLoader.load(FontManifest.self, resource: manifestResourceName)
        } catch {
            assertionFailure("Font manifest load failed: \(error)")
            return FontManifest(schemaVersion: "0", fonts: [])
        }
    }()

    public static let fonts: [FontAsset] = manifest.fonts.map(FontAsset.init)

    private static let fontsByID: [String: FontAsset] = Dictionary(
        uniqueKeysWithValues: fonts.map { ($0.id, $0) }
    )

    /// 可用于 TextStep 的字体（manifest `usage` 含 `editor_text`）。
    public static var editorTextFonts: [FontAsset] {
        fonts.filter(\.supportsEditorText)
    }

    /// TextStep UI 展示全部 manifest 字体（≥ 6 款）。
    public static var allEditorFonts: [FontAsset] {
        fonts
    }

    public static func font(for id: String) -> FontAsset? {
        fontsByID[id]
    }

    public static func postScriptName(for id: String) -> String {
        font(for: id)?.postScriptName ?? "PingFangSC-Regular"
    }

    public static var satisfiesMinimumCount: Bool {
        fonts.count >= minimumFontCount
    }

    public static var allFontsAreCommerciallyLicensed: Bool {
        fonts.allSatisfy(\.commercial)
    }

    public static var licenseFilesAreDeclared: Bool {
        fonts.allSatisfy { !$0.licenseFile.isEmpty }
    }

    /// 从宿主 Bundle 注册 manifest 中的 TTF（ODR: editor-fonts）。
    @discardableResult
    public static func registerFonts(from bundle: Bundle) -> Int {
        #if canImport(UIKit)
        var registered = 0
        for asset in fonts {
            let directory = (asset.filePath as NSString).deletingLastPathComponent
            let filename = (asset.filePath as NSString).lastPathComponent
            let basename = (filename as NSString).deletingPathExtension
            guard let url = bundle.url(
                forResource: basename,
                withExtension: "ttf",
                subdirectory: directory.isEmpty ? nil : "Fonts/\(directory)"
            ) ?? bundle.url(forResource: basename, withExtension: "ttf") else {
                continue
            }
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                registered += 1
            }
        }
        return registered
        #else
        return 0
        #endif
    }
}
