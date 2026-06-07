import CoreImage
import XCTest
@testable import BabyCameraCamera

final class RealtimeFilterPipelineTests: XCTestCase {
    private func makeTestImage() -> CIImage {
        let color = CIColor(red: 0.4, green: 0.6, blue: 0.9)
        return CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: color])!
            .outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    }

    func testPipelineUsesMetalDevice() {
        let pipeline = RealtimeFilterPipeline()
        XCTAssertNotNil(pipeline.device)
        XCTAssertNotNil(pipeline.context)
    }

    func testNoneFilterPassesThroughImage() {
        let pipeline = RealtimeFilterPipeline()
        let input = makeTestImage()
        let output = pipeline.applyFilter(to: input)
        XCTAssertEqual(output.extent, input.extent)
    }

    func testEachPreviewFilterProducesOutput() {
        let pipeline = RealtimeFilterPipeline()
        let input = makeTestImage()

        for preset in RealtimeFilterCatalog.previewPresets {
            pipeline.selectFilter(preset.id)
            let output = pipeline.applyFilter(to: input)
            XCTAssertFalse(output.extent.isEmpty, "滤镜 \(preset.id) 未产生输出")
        }
    }

    func testSelectFilterUpdatesConfiguration() {
        let pipeline = RealtimeFilterPipeline()
        pipeline.selectFilter(.noir)
        XCTAssertEqual(pipeline.configuration.activeFilter, .noir)
        XCTAssertEqual(pipeline.configuration.filterIntensity, 1.0, accuracy: 0.001)
    }

    func testFramePacingAt30FPS() {
        let pipeline = RealtimeFilterPipeline()
        let base: CFAbsoluteTime = 1000

        XCTAssertTrue(pipeline.shouldProcessFrame(at: base))
        XCTAssertFalse(pipeline.shouldProcessFrame(at: base + 0.01))
        XCTAssertFalse(pipeline.shouldProcessFrame(at: base + 0.02))
        XCTAssertTrue(pipeline.shouldProcessFrame(at: base + 1.0 / 30.0))
    }

    func testResetFramePacingAllowsImmediateFrame() {
        let pipeline = RealtimeFilterPipeline()
        let base: CFAbsoluteTime = 2000

        XCTAssertTrue(pipeline.shouldProcessFrame(at: base))
        XCTAssertFalse(pipeline.shouldProcessFrame(at: base + 0.001))

        pipeline.resetFramePacing()
        XCTAssertTrue(pipeline.shouldProcessFrame(at: base + 0.001))
    }

    func testUpdateConfigurationPreservesCustomIntensity() {
        let pipeline = RealtimeFilterPipeline(
            configuration: RealtimeFilterPipelineConfiguration(
                activeFilter: .sepia,
                filterIntensity: 0.42,
                targetFrameRate: 30
            )
        )
        let output = pipeline.applyFilter(to: makeTestImage())
        XCTAssertFalse(output.extent.isEmpty)
        XCTAssertEqual(pipeline.configuration.filterIntensity, 0.42, accuracy: 0.001)
    }
}
