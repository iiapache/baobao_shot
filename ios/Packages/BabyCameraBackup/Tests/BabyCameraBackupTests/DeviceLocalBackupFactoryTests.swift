import XCTest
@testable import BabyCameraBackup

final class DeviceLocalBackupFactoryTests: XCTestCase {
    func testForceStubOverridesLiveInfoPlist() {
        let bundle = makeBundle(
            iCloudLive: true,
            photosLive: true
        )

        XCTAssertEqual(
            ICloudProviderFactory.currentMode(bundle: bundle, forceStub: true),
            .stub
        )
        XCTAssertEqual(
            PhotosProviderFactory.currentMode(bundle: bundle, forceStub: true),
            .stub
        )
    }

    func testDebugDefaultsToStubMode() {
        let bundle = makeBundle(iCloudLive: false, photosLive: false)

        XCTAssertEqual(ICloudProviderFactory.currentMode(bundle: bundle), .stub)
        XCTAssertEqual(PhotosProviderFactory.currentMode(bundle: bundle), .stub)
    }

    func testStagingDefaultsToLiveMode() {
        let bundle = makeBundle(iCloudLive: true, photosLive: true)

        XCTAssertEqual(ICloudProviderFactory.currentMode(bundle: bundle), .live)
        XCTAssertEqual(PhotosProviderFactory.currentMode(bundle: bundle), .live)
    }

    func testICloudStubProviderAuthorizesWithoutCloudKit() async throws {
        let database = StubCloudKitPrivateDatabase()
        let provider = ICloudProviderFactory.make(
            forceStub: true,
            database: database
        )

        try await provider.authorize()
        XCTAssertEqual(database.accountStatusCallCount, 1)
    }

    func testPhotosStubProviderAuthorizesWithoutSystemDialog() async throws {
        let permission = StubPhotosAddOnlyPermissionService(status: .authorized)
        let provider = PhotosProviderFactory.make(
            forceStub: true,
            permission: permission
        )

        try await provider.authorize()
    }

    func testPhotosStubBindWritesDeterministicAssetID() async throws {
        let fileURL = try makeTemporaryFile(named: "photo.heic", contents: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let provider = PhotosProviderFactory.make(forceStub: true)
        let receipt = try await provider.upload(
            BackupItem(
                photoId: "p1",
                sha256: "hash-a",
                filePath: fileURL.path,
                mimeType: "image/heic",
                byteSize: 1,
                updatedAt: 100
            )
        )

        XCTAssertTrue(receipt.remoteId.hasPrefix("stub-photos-"))
    }

    func testUserDefaultsLedgerPersistsEntries() async throws {
        let defaults = UserDefaults(suiteName: "DeviceLocalBackupFactoryTests.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let ledger = UserDefaultsPhotosWriteLedger(defaults: defaults)
        await ledger.record(item: BackupRemoteItem(remoteId: "asset-1", sha256: "hash-a"), byteSize: 100)

        let reloaded = UserDefaultsPhotosWriteLedger(defaults: defaults)
        let page = await reloaded.page(after: nil, limit: 10)

        XCTAssertEqual(page.items.map(\.remoteId), ["asset-1"])
        XCTAssertEqual(await reloaded.totalUsedBytes(), 100)
    }

    private func makeBundle(iCloudLive: Bool, photosLive: Bool) -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            DeviceLocalBackupConfiguration.useLiveICloudInfoPlistKey: iCloudLive ? "YES" : "NO",
            DeviceLocalBackupConfiguration.useLivePhotosInfoPlistKey: photosLive ? "YES" : "NO",
            DeviceLocalBackupConfiguration.iCloudContainerInfoPlistKey: "iCloud.app.babycamera",
        ]
        let plistURL = directory.appendingPathComponent("Info.plist")
        try! (plist as NSDictionary).write(to: plistURL)

        return Bundle(path: directory.path)!
    }

    private func makeTemporaryFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceLocalBackupFactoryTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try contents.write(to: fileURL)
        return fileURL
    }
}
