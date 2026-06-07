import CoreImage
import XCTest
@testable import BabyCameraEditor

final class TemplateManifestTests: XCTestCase {
    private let testExtent = CGRect(x: 0, y: 0, width: 128, height: 128)

    override func tearDown() {
        TemplateCatalog.remoteProvider = nil
        TemplateCatalog.resetForTesting()
        super.tearDown()
    }

    // MARK: - Catalog manifest

    func testTemplateCatalogMeetsMinimumCount() {
        XCTAssertTrue(TemplateCatalog.satisfiesMinimumCount)
        XCTAssertGreaterThanOrEqual(TemplateCatalog.templates.count, 12)
    }

    func testTemplateCatalogHasAllCategories() {
        XCTAssertTrue(TemplateCatalog.hasAllCategoriesRepresented)
        for category in TemplateCategoryID.allCases {
            let items = TemplateCatalog.templates(in: category)
            XCTAssertFalse(items.isEmpty, "分类 \(category.displayName) 应有模板")
        }
    }

    func testTemplateCatalogLookupByID() {
        let asset = TemplateCatalog.template(for: "tpl_growth_01")
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.category, .growthCard)
        XCTAssertEqual(asset?.configSvcKey, "editor.templates.tpl_growth_01")
    }

    func testCatalogManifestParsesFromBundle() throws {
        let catalog = try TemplateManifestLoader.loadCatalogFromBundle()
        XCTAssertEqual(catalog.schemaVersion, "1.0.0")
        XCTAssertEqual(catalog.templates.count, 12)
        XCTAssertEqual(catalog.categories.count, 3)
    }

    func testDetailManifestParsesFromBundle() throws {
        let detail = try TemplateManifestLoader.loadDetailFromBundle(
            manifestPath: "templates/growth-card/tpl_growth_01/manifest.json"
        )
        XCTAssertEqual(detail.id, "tpl_growth_01")
        XCTAssertEqual(detail.editorStepType, "TemplateStep")
        XCTAssertEqual(detail.placeholders.count, 4)
        XCTAssertTrue(detail.steps.isEmpty)
    }

    // MARK: - Placeholder resolution

    func testPlaceholderResolverReplacesKnownKeys() {
        let resolved = TemplatePlaceholderResolver.resolve(
            "第 {{day_count}} 天 · {{baby_name}}",
            placeholders: [
                TemplatePlaceholder(key: "day_count", value: "100"),
                TemplatePlaceholder(key: "baby_name", value: "小宝"),
            ]
        )
        XCTAssertEqual(resolved, "第 100 天 · 小宝")
    }

    func testPlaceholderResolverLeavesUnknownKeysUntouched() {
        let resolved = TemplatePlaceholderResolver.resolve(
            "{{capture_date}}",
            placeholders: [TemplatePlaceholder(key: "baby_name", value: "小宝")]
        )
        XCTAssertEqual(resolved, "{{capture_date}}")
    }

    // MARK: - TemplateStep build & apply

    func testMakeTemplateStepBuildsTextNestedSteps() throws {
        let step = try TemplateCatalog.makeTemplateStep(
            templateID: "tpl_growth_01",
            placeholders: [
                TemplatePlaceholder(key: "baby_name", value: "豆豆"),
                TemplatePlaceholder(key: "day_count", value: "42"),
                TemplatePlaceholder(key: "capture_date", value: "2026-06-06"),
            ]
        )

        XCTAssertEqual(step.templateID, "tpl_growth_01")
        XCTAssertEqual(step.nestedSteps.count, 3)

        guard case let .text(nameStep) = step.nestedSteps[0] else {
            return XCTFail("expected text step for baby_name")
        }
        XCTAssertEqual(nameStep.text, "豆豆")

        guard case let .text(dayStep) = step.nestedSteps[1] else {
            return XCTFail("expected text step for day_count")
        }
        XCTAssertEqual(dayStep.text, "第 42 天")

        guard case let .text(dateStep) = step.nestedSteps[2] else {
            return XCTFail("expected text step for capture_date")
        }
        XCTAssertEqual(dateStep.text, "2026-06-06")
    }

    func testTemplateStepApplyProducesOutput() throws {
        let step = try TemplateCatalog.makeTemplateStep(
            templateID: "tpl_hundred_01",
            placeholders: [
                TemplatePlaceholder(key: "baby_name", value: "测试"),
                TemplatePlaceholder(key: "capture_date", value: "2026-01-01"),
            ]
        )
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent)
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    // MARK: - Remote provider (mock config-svc)

    func testRemoteCatalogMergeOverridesLocalTemplate() throws {
        let local = try TemplateManifestLoader.loadCatalogFromBundle()
        let remoteJSON = """
        {
          "schemaVersion": "1.0.1",
          "categories": [],
          "templates": [
            {
              "id": "tpl_growth_01",
              "name": "远端覆盖 · 简约白",
              "category": "growth-card",
              "categoryLabel": "成长卡片",
              "manifestPath": "templates/growth-card/tpl_growth_01/manifest.json",
              "preview": "templates/growth-card/tpl_growth_01/preview.jpg",
              "remoteConfigurable": true,
              "configSvcKey": "editor.templates.tpl_growth_01"
            }
          ]
        }
        """.data(using: .utf8)!
        let remote = try TemplateManifestLoader.loadCatalog(from: remoteJSON)
        let merged = TemplateManifestLoader.mergeCatalog(local: local, remote: remote)

        let overridden = merged.templates.first { $0.id == "tpl_growth_01" }
        XCTAssertEqual(overridden?.name, "远端覆盖 · 简约白")
        XCTAssertEqual(merged.templates.count, 12)
        XCTAssertEqual(merged.schemaVersion, "1.0.1")
    }

    func testRefreshFromRemoteAppliesDetailOverride() async throws {
        let remoteDetailJSON = """
        {
          "schemaVersion": "1.0.1",
          "id": "tpl_growth_01",
          "name": "远端 detail",
          "category": "growth-card",
          "categoryLabel": "成长卡片",
          "canvas": { "width": 1080, "height": 1440, "dpi": 72 },
          "placeholders": [
            {
              "id": "baby_name",
              "type": "text",
              "label": "宝宝昵称",
              "fontId": "font_baobao_rounded",
              "defaultValue": "{{baby_name}}",
              "rect": { "x": 0.1, "y": 0.75, "width": 0.8, "height": 0.08 },
              "editable": true
            }
          ],
          "steps": [
            {
              "kind": "filter",
              "payload": { "filterID": "fade", "intensity": 0.5 }
            }
          ],
          "resources": {
            "background": "templates/growth-card/tpl_growth_01/background.png",
            "overlay": "templates/growth-card/tpl_growth_01/overlay.png",
            "fonts": ["font_baobao_rounded"],
            "stickers": []
          },
          "editorStepType": "TemplateStep"
        }
        """.data(using: .utf8)!

        let provider = MockRemoteTemplateProvider(
            templateData: ["editor.templates.tpl_growth_01": remoteDetailJSON]
        )
        TemplateCatalog.remoteProvider = provider

        try await TemplateCatalog.refreshFromRemote()
        let detail = try TemplateCatalog.detailManifest(for: "tpl_growth_01")
        XCTAssertEqual(detail.name, "远端 detail")
        XCTAssertEqual(detail.steps.count, 1)

        let step = try TemplateCatalog.makeTemplateStep(
            templateID: "tpl_growth_01",
            placeholders: [TemplatePlaceholder(key: "baby_name", value: "远端宝宝")]
        )
        XCTAssertEqual(step.nestedSteps.count, 2)
        XCTAssertEqual(step.nestedSteps[0].kind, .filter)
    }

    func testDetailManifestRejectsUnsupportedEditorStepType() {
        let json = """
        {
          "schemaVersion": "1.0.0",
          "id": "bad_tpl",
          "name": "bad",
          "category": "growth-card",
          "categoryLabel": "成长卡片",
          "canvas": { "width": 1080, "height": 1440 },
          "placeholders": [],
          "steps": [],
          "resources": {
            "background": "bg.png",
            "overlay": "overlay.png",
            "fonts": [],
            "stickers": []
          },
          "editorStepType": "ScriptStep"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try TemplateManifestLoader.loadDetail(from: json)) { error in
            guard case TemplateManifestLoader.Error.unsupportedEditorStepType("ScriptStep") = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }
}

private struct MockRemoteTemplateProvider: RemoteTemplateProvider {
    var catalogData: Data?
    var templateData: [String: Data]

    func fetchCatalogManifest() async throws -> Data? {
        catalogData
    }

    func fetchTemplateManifest(configSvcKey: String) async throws -> Data? {
        templateData[configSvcKey]
    }
}
