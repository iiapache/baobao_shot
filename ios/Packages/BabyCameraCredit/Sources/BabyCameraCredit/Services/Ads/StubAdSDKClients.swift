import Foundation

/// 无真实 SDK 依赖的联盟 stub，便于单测与模拟器联调。
public struct StubAdSDKClient: AdSDKClient, @unchecked Sendable {
    public let network: AdNetwork
    private let shouldFailLoad: Bool
    private let showResult: AdShowResult
    private let transactionIDFactory: @Sendable () -> String
    private(set) var initializeCallCount = 0
    private(set) var loadCalls: [(AdPlacement, String)] = []
    private(set) var showCalls: [AdCreative] = []
    private let lock = NSLock()

    public init(
        network: AdNetwork,
        shouldFailLoad: Bool = false,
        showResult: AdShowResult = .impressed(transactionID: "stub-trans-default"),
        transactionIDFactory: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.network = network
        self.shouldFailLoad = shouldFailLoad
        self.showResult = showResult
        self.transactionIDFactory = transactionIDFactory
    }

    public func initialize() async throws {
        lock.withLock { initializeCallCount += 1 }
    }

    public func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        lock.withLock { loadCalls.append((placement, placementID)) }
        if shouldFailLoad {
            throw AdManagerError.loadFailed("stub load failed for \(network.rawValue)")
        }
        return AdCreative(
            network: network,
            placement: placement,
            placementID: placementID,
            transactionID: transactionIDFactory()
        )
    }

    public func show(_ creative: AdCreative) async throws -> AdShowResult {
        lock.withLock { showCalls.append(creative) }
        switch showResult {
        case .failed(let message):
            throw AdManagerError.showFailed(message)
        default:
            return showResult
        }
    }

    public func snapshot() -> (
        initializeCallCount: Int,
        loadCalls: [(AdPlacement, String)],
        showCalls: [AdCreative]
    ) {
        lock.withLock {
            (initializeCallCount, loadCalls, showCalls)
        }
    }
}

public enum StubAdSDKFactory {
    public static func makeCNClients(
        pangleShowResult: AdShowResult = .impressed(transactionID: "pangle-trans"),
        gdtShowResult: AdShowResult = .impressed(transactionID: "gdt-trans")
    ) -> [AdSDKClient] {
        [
            StubAdSDKClient(network: .pangle, showResult: pangleShowResult),
            StubAdSDKClient(network: .gdt, showResult: gdtShowResult),
        ]
    }

    public static func makeOSClients(
        showResult: AdShowResult = .impressed(transactionID: "admob-trans")
    ) -> [AdSDKClient] {
        [StubAdSDKClient(network: .admob, showResult: showResult)]
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
