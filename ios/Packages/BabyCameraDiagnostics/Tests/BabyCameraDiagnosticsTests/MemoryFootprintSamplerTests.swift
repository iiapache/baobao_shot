import XCTest
@testable import BabyCameraDiagnostics

#if DEBUG
final class MockMemoryFootprintReader: MemoryFootprintReading {
    var values: [UInt64]
    private(set) var readCount = 0

    init(values: [UInt64]) {
        self.values = values
    }

    func residentSizeBytes() -> UInt64 {
        let index = min(readCount, max(values.count - 1, 0))
        readCount += 1
        guard !values.isEmpty else { return 0 }
        return values[index]
    }
}

final class MemoryFootprintSamplerTests: XCTestCase {
    func testBudgetIs200Megabytes() {
        XCTAssertEqual(MemoryFootprintSampler.memoryBudgetBytes, 200 * 1_024 * 1_024)
    }

    func testSampleTracksPeakAcrossReads() {
        let reader = MockMemoryFootprintReader(values: [50 * 1_024 * 1_024, 120 * 1_024 * 1_024, 80 * 1_024 * 1_024])
        let sampler = MemoryFootprintSampler(reader: reader)

        let first = sampler.sample(at: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(first.residentBytes, 50 * 1_024 * 1_024)
        XCTAssertEqual(first.peakBytes, 50 * 1_024 * 1_024)
        XCTAssertFalse(first.exceedsBudget)

        let second = sampler.sample(at: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(second.peakBytes, 120 * 1_024 * 1_024)
        XCTAssertFalse(second.exceedsBudget)

        let third = sampler.sample(at: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(third.peakBytes, 120 * 1_024 * 1_024)
        XCTAssertEqual(sampler.currentPeakBytes(), 120 * 1_024 * 1_024)
    }

    func testExceedsBudgetWhenPeakAbove200MB() {
        let overBudget = UInt64(201 * 1_024 * 1_024)
        let reader = MockMemoryFootprintReader(values: [overBudget])
        let sampler = MemoryFootprintSampler(reader: reader)

        let sample = sampler.sample()
        XCTAssertTrue(sample.exceedsBudget)
        XCTAssertTrue(sampler.exceedsBudget())
    }

    func testResetPeakClearsTrackedMaximum() {
        let reader = MockMemoryFootprintReader(values: [180 * 1_024 * 1_024, 90 * 1_024 * 1_024])
        let sampler = MemoryFootprintSampler(reader: reader)

        _ = sampler.sample()
        XCTAssertEqual(sampler.currentPeakBytes(), 180 * 1_024 * 1_024)

        sampler.resetPeak()
        let afterReset = sampler.sample()
        XCTAssertEqual(afterReset.peakBytes, 90 * 1_024 * 1_024)
        XCTAssertFalse(afterReset.exceedsBudget)
    }

    func testFormattedSummaryMarksPassAndFail() {
        let sampler = MemoryFootprintSampler(reader: MockMemoryFootprintReader(values: [0]))
        let passSample = MemoryFootprintSample(
            residentBytes: 150 * 1_024 * 1_024,
            peakBytes: 180 * 1_024 * 1_024,
            budgetBytes: MemoryFootprintSampler.memoryBudgetBytes,
            capturedAt: Date()
        )
        XCTAssertTrue(sampler.formattedSummary(sample: passSample).hasSuffix("PASS"))

        let failSample = MemoryFootprintSample(
            residentBytes: 210 * 1_024 * 1_024,
            peakBytes: 210 * 1_024 * 1_024,
            budgetBytes: MemoryFootprintSampler.memoryBudgetBytes,
            capturedAt: Date()
        )
        XCTAssertTrue(sampler.formattedSummary(sample: failSample).hasSuffix("FAIL"))
    }
}

final class CrashReportingConfigurationTests: XCTestCase {
    func testParsesInfoPlistKeys() {
        let config = CrashReportingConfiguration(infoDictionary: [
            "SentryDSN": "https://example@sentry.io/123",
            "BuglyAppID": "bugly-test-app-id",
            "AppEnvironment": "staging",
            "CrashReportingEnabled": true,
        ])
        XCTAssertEqual(config.sentryDSN, "https://example@sentry.io/123")
        XCTAssertEqual(config.buglyAppID, "bugly-test-app-id")
        XCTAssertEqual(config.environment, "staging")
        XCTAssertTrue(config.isEnabled)
    }

    func testEmptyStringsTreatedAsMissing() {
        let config = CrashReportingConfiguration(infoDictionary: [
            "SentryDSN": "   ",
            "BuglyAppID": "",
            "CrashReportingEnabled": "NO",
        ])
        XCTAssertNil(config.sentryDSN)
        XCTAssertNil(config.buglyAppID)
        XCTAssertFalse(config.isEnabled)
    }
}
#else
final class MemoryFootprintSamplerTests: XCTestCase {
    func testReleaseBudgetConstant() {
        XCTAssertEqual(MemoryFootprintSampler.memoryBudgetBytes, 200 * 1_024 * 1_024)
        XCTAssertEqual(MemoryFootprintSampler.currentPeakBytes(), 0)
        XCTAssertFalse(MemoryFootprintSampler.exceedsBudget())
    }
}
#endif
