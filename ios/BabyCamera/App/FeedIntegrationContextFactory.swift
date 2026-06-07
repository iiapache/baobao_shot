import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamily
import BabyCameraFamilyFeed
import BabyCameraNetwork
import Database
import Foundation

enum FeedBootstrapError: LocalizedError {
    case missingFamily
    case missingBaby

    var errorDescription: String? {
        switch self {
        case .missingFamily:
            return "未找到家庭，请先完成新手引导或加入家庭"
        case .missingBaby:
            return "未找到宝宝档案，请先创建宝宝"
        }
    }
}

/// App 层家庭圈联调工厂（NAV-06）：解析 familyId / babyId，装配 FeedIntegrationContext。
enum FeedIntegrationContextFactory {
    struct BootstrapResult {
        let context: FeedIntegrationContext
        let babyEnvironment: CurrentBabyEnvironment
        let currentBaby: BabyProfile
        let mentionCandidates: [FeedMentionCandidate]
        let feedCoordinator: FeedCoordinator
    }

    static func bootstrap(
        session: AuthSession,
        accountCoordinator: AccountCoordinator,
        appDatabase: AppDatabase,
        babyEnvironment: CurrentBabyEnvironment,
        familyId: String? = nil,
        region: AppRegion = .cn,
        urlSession: URLSession = NetworkSessionFactory.makeSession()
    ) async throws -> BootstrapResult {
        let tokenStore = accountCoordinator.authService.tokenStore
        let regionConfig = RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: resolveDeviceId()
        )
        let client = makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            session: urlSession
        )

        let resolvedFamilyId = try await resolveFamilyId(
            explicit: familyId,
            tokenStore: tokenStore,
            region: region,
            regionConfig: regionConfig,
            appDatabase: appDatabase,
            urlSession: urlSession
        )

        let babyRepository = appDatabase.makeBabyRepository()
        let babyService = BabyService(
            familyId: resolvedFamilyId,
            repository: babyRepository,
            client: client
        )
        await MainTabBabyLoader.load(into: babyEnvironment, database: appDatabase)

        if let babies = try? await babyService.listBabies() {
            babyEnvironment.replaceBabies(babies)
        } else if babyEnvironment.babies.isEmpty {
            let records = try await babyRepository.fetchAll(familyId: resolvedFamilyId)
            let profiles = records.map(BabyProfile.init(record:))
            guard !profiles.isEmpty else {
                throw FeedBootstrapError.missingBaby
            }
            babyEnvironment.replaceBabies(profiles)
        }

        guard let currentBaby = babyEnvironment.currentBaby else {
            throw FeedBootstrapError.missingBaby
        }

        let context = FamilyFeedIntegration.makeContext(
            dependencies: .init(
                appDatabase: appDatabase,
                tokenStore: tokenStore,
                familyId: resolvedFamilyId,
                currentUserId: session.userId,
                region: region,
                session: urlSession
            )
        )

        let familyService = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )
        let mentionCandidates: [FeedMentionCandidate]
        if let members = try? await familyService.listMembers(familyId: resolvedFamilyId) {
            mentionCandidates = members.map {
                FeedMentionCandidate(id: $0.id, nickname: $0.nickname.isEmpty ? $0.id : $0.nickname)
            }
        } else {
            mentionCandidates = []
        }

        let feedCoordinator = FamilyFeedIntegration.makeFeedCoordinator(
            context: context,
            currentBabyEnvironment: babyEnvironment,
            mentionCandidates: mentionCandidates
        )
        _ = feedCoordinator.attachFeedList()

        return BootstrapResult(
            context: context,
            babyEnvironment: babyEnvironment,
            currentBaby: currentBaby,
            mentionCandidates: mentionCandidates,
            feedCoordinator: feedCoordinator
        )
    }

    private static func resolveFamilyId(
        explicit: String?,
        tokenStore: TokenStore,
        region: AppRegion,
        regionConfig: RegionConfig,
        appDatabase: AppDatabase,
        urlSession: URLSession
    ) async throws -> String {
        if let explicit, !explicit.isEmpty {
            return explicit
        }

        let familyRepository = appDatabase.makeFamilyRepository()
        let localFamilies = try await familyRepository.fetchAll()
        if let first = localFamilies.first {
            return first.id
        }

        let babyRepository = appDatabase.makeBabyRepository()
        if let babyId = UserDefaults.standard.string(forKey: "com.babycamera.currentBabyId"),
           let baby = try await babyRepository.fetch(id: babyId) {
            return baby.familyId
        }

        let familyService = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )
        let families = try await familyService.listFamilies()
        guard let first = families.first else {
            throw FeedBootstrapError.missingFamily
        }
        return first.id
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
