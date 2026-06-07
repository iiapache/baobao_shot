import BabyCameraNetwork
import Foundation

public struct IAPServiceConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession
    public let maxVerifyRetries: Int
    public let retryBaseDelay: TimeInterval
    public let appAttestAttachmentProvider: AppAttestAttachmentProvider?

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared,
        maxVerifyRetries: Int = 3,
        retryBaseDelay: TimeInterval = 0.5,
        appAttestAttachmentProvider: AppAttestAttachmentProvider? = nil
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: IAPServiceConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
        self.maxVerifyRetries = max(1, maxVerifyRetries)
        self.retryBaseDelay = retryBaseDelay
        self.appAttestAttachmentProvider = appAttestAttachmentProvider
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

public final class IAPService: @unchecked Sendable {
    private let configuration: IAPServiceConfiguration
    private let storeClient: IAPStoreClient
    private let pendingStore: PendingIAPReceiptStoring
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private let processingLock = NSLock()
    private var inFlightTransactionIDs: Set<String> = []
    private var updatesTask: Task<Void, Never>?

    public init(
        configuration: IAPServiceConfiguration = IAPServiceConfiguration(),
        storeClient: IAPStoreClient = StoreKitPurchaseClient(),
        pendingStore: PendingIAPReceiptStoring = PendingIAPReceiptStore(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.configuration = configuration
        self.storeClient = storeClient
        self.pendingStore = pendingStore
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// 启动 Transaction.updates 监听，并处理 StoreKit 未完成交易与本地待上送队列。
    public func start() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            await self.bootstrap()
            for await transaction in self.storeClient.transactionUpdates() {
                guard !Task.isCancelled else { break }
                await self.processTransactionQuietly(transaction)
            }
        }
    }

    public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    public func loadProducts() async throws -> [IAPProduct] {
        try await storeClient.loadProducts(ids: CreditIAPProductID.all)
    }

    /// StoreKit 购买 → 上送 JWS → finish(transaction)。
    public func purchase(productID: String) async throws -> IAPVerifyOutcome {
        let transaction = try await storeClient.purchase(productID: productID)
        return try await processTransaction(transaction)
    }

    /// 启动时或网络恢复后显式重试待上送收据。
    public func retryPendingUploads() async {
        await bootstrapPendingOnly()
    }

    private func bootstrap() async {
        let unfinished = await storeClient.unfinishedTransactions()
        for transaction in unfinished {
            await processTransactionQuietly(transaction)
        }
        await bootstrapPendingOnly()
    }

    private func bootstrapPendingOnly() async {
        for transaction in pendingStore.loadAll() {
            await processTransactionQuietly(transaction)
        }
    }

    private func processTransactionQuietly(_ transaction: IAPVerifiedTransaction) async {
        do {
            _ = try await processTransaction(transaction)
        } catch {
            // 保留 pending / StoreKit unfinished，等待下次重试
        }
    }

    @discardableResult
    private func processTransaction(_ transaction: IAPVerifiedTransaction) async throws -> IAPVerifyOutcome {
        guard beginProcessing(transaction.transactionID) else {
            throw IAPServiceError.verifyFailed
        }
        defer { endProcessing(transaction.transactionID) }

        pendingStore.save(transaction)

        do {
            let verifyData = try await verifyWithRetry(transaction)
            try await storeClient.finish(transactionID: transaction.storeTransactionID)
            pendingStore.remove(transactionID: transaction.transactionID)
            return IAPVerifyOutcome(transaction: transaction, verifyData: verifyData)
        } catch let error as IAPServiceError where error == .nonRetriableVerifyFailure {
            pendingStore.remove(transactionID: transaction.transactionID)
            throw error
        }
    }

    private func verifyWithRetry(_ transaction: IAPVerifiedTransaction) async throws -> IAPVerifyData {
        var lastError: Error = IAPServiceError.verifyFailed

        for attempt in 0..<configuration.maxVerifyRetries {
            do {
                return try await verify(transaction)
            } catch let error as IAPServiceError where error == .nonRetriableVerifyFailure {
                throw error
            } catch {
                lastError = error
                guard shouldRetry(error), attempt < configuration.maxVerifyRetries - 1 else {
                    throw error
                }
                let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError
    }

    private func verify(_ transaction: IAPVerifiedTransaction) async throws -> IAPVerifyData {
        guard configuration.tokenStore.refreshToken() != nil else {
            throw IAPServiceError.notAuthenticated
        }

        let api = CreditsAPI(client: clientFactory(configuration.tokenStore))
        do {
            let appAttest = await resolveAppAttestPayload(
                transactionId: transaction.transactionID,
                productId: transaction.productID
            )
            return try await api.iapVerify(
                IAPVerifyRequest(
                    transactionId: transaction.transactionID,
                    signedTransaction: transaction.signedTransaction,
                    productId: transaction.productID,
                    appAttest: appAttest
                )
            )
        } catch let error as APIError {
            if shouldRetry(error) {
                throw error
            }
            throw IAPServiceError.nonRetriableVerifyFailure
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is NetworkTransportError {
            return true
        }
        guard let apiError = error as? APIError else {
            return false
        }
        if let status = apiError.httpStatusCode, status >= 500 {
            return true
        }
        switch apiError.code {
        case .sysInternal, .sysUpstreamUnavailable, .commonRateLimit:
            return true
        default:
            return false
        }
    }

    private func beginProcessing(_ transactionID: String) -> Bool {
        processingLock.lock()
        defer { processingLock.unlock() }
        if inFlightTransactionIDs.contains(transactionID) {
            return false
        }
        inFlightTransactionIDs.insert(transactionID)
        return true
    }

    private func endProcessing(_ transactionID: String) {
        processingLock.lock()
        defer { processingLock.unlock() }
        inFlightTransactionIDs.remove(transactionID)
    }

    private func resolveAppAttestPayload(
        transactionId: String,
        productId: String
    ) async -> AppAttestPayload? {
        guard let provider = configuration.appAttestAttachmentProvider else {
            return nil
        }
        guard let attachment = await provider(transactionId, productId) else {
            return nil
        }
        return AppAttestPayload(attachment: attachment)
    }
}
