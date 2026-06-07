import CoreImage
import XCTest
@testable import BabyCameraEditor

final class AdjustStepTests: XCTestCase {
    private let testExtent = CGRect(x: 0, y: 0, width: 64, height: 64)

    func testDefaultParametersAreNeutral() {
        let params = AdjustParameters()
        XCTAssertTrue(params.isNeutral)
        XCTAssertEqual(params.brightness, AdjustParameterRanges.brightness.default)
        XCTAssertEqual(params.temperature, AdjustParameterRanges.temperature.default)
    }

    func testClampKeepsValuesInRange() {
        let raw = AdjustParameters(
            brightness: 10,
            contrast: -1,
            saturation: 99,
            temperature: 1000,
            shadows: -5,
            highlights: 5,
            sharpness: 3
        )
        let clamped = raw.clamped()
        XCTAssertEqual(clamped.brightness, AdjustParameterRanges.brightness.max)
        XCTAssertEqual(clamped.contrast, AdjustParameterRanges.contrast.min)
        XCTAssertEqual(clamped.saturation, AdjustParameterRanges.saturation.max)
        XCTAssertEqual(clamped.temperature, AdjustParameterRanges.temperature.min)
        XCTAssertEqual(clamped.shadows, AdjustParameterRanges.shadows.min)
        XCTAssertEqual(clamped.highlights, AdjustParameterRanges.highlights.max)
        XCTAssertEqual(clamped.sharpness, AdjustParameterRanges.sharpness.max)
    }

    func testNormalizedAndDenormalizedAreInverse() {
        let range = AdjustParameterRanges.brightness
        let original = 0.25
        let normalized = range.normalized(original)
        let restored = range.denormalized(normalized)
        XCTAssertEqual(restored, original, accuracy: 0.0001)
    }

    func testNeutralAdjustIsPassthrough() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent)
        let step = AdjustStep(parameters: AdjustParameters())
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    func testBrightnessAdjustProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.5, green: 0.5, blue: 0.5)
        let step = AdjustStep(parameters: AdjustParameters(brightness: 0.3))
        let output = step.apply(to: base)
        XCTAssertFalse(output.extent.isEmpty)
    }

    func testTemperatureAdjustProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.5, green: 0.5, blue: 0.5)
        let step = AdjustStep(parameters: AdjustParameters(temperature: 4500))
        let output = step.apply(to: base)
        XCTAssertFalse(output.extent.isEmpty)
    }

    func testShadowHighlightAdjustProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.4, green: 0.4, blue: 0.4)
        let step = AdjustStep(parameters: AdjustParameters(shadows: 0.4, highlights: -0.3))
        let output = step.apply(to: base)
        XCTAssertFalse(output.extent.isEmpty)
    }

    func testAdjustPanelBindingClampsOnCommit() {
        var binding = AdjustPanelBinding(parameters: AdjustParameters(brightness: 99))
        let step = binding.makeStep()
        XCTAssertEqual(step.parameters.brightness, AdjustParameterRanges.brightness.max)
    }

    func testAdjustStepCodableRoundTrip() throws {
        let step = AdjustStep(parameters: AdjustParameters(
            brightness: 0.1,
            contrast: 1.2,
            saturation: 0.8,
            temperature: 5200,
            shadows: 0.2,
            highlights: -0.1,
            sharpness: 0.5
        ))
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(AdjustStep.self, from: data)
        XCTAssertEqual(decoded, step)
    }
}
