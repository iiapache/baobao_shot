import BabyCameraNetwork
import BabyCameraOnboarding
import BabyCameraPermissions
import DesignSystem
import Foundation

@MainActor
public final class PrivacySettingsViewModel: ObservableObject {
    @Published public private(set) var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    @Published public private(set) var compliance = ComplianceConfig.defaults(for: .cn)
    @Published public private(set) var complianceErrorMessage: String?

    public let profile: UserProfile?
    private let permissionManager: any PermissionManager
    private let complianceService: (any ComplianceConfigServing)?
    private let region: AppRegion

    public init(
        profile: UserProfile?,
        permissionManager: any PermissionManager,
        complianceService: (any ComplianceConfigServing)? = nil,
        region: AppRegion = .cn
    ) {
        self.profile = profile
        self.permissionManager = permissionManager
        self.complianceService = complianceService
        self.region = profile?.region == AppRegion.os.rawValue ? .os : region
        self.compliance = ComplianceConfig.defaults(for: self.region)
    }

    public var hasChildDataConsent: Bool {
        ChildDataConsent.hasValidConsent(in: profile)
    }

    public var childConsentVersion: String {
        ChildDataConsent.currentVersion
    }

    public func refresh() async {
        await permissionManager.refreshNotificationStatus()
        var statuses: [PermissionType: PermissionStatus] = [:]
        for type in PermissionType.allCases {
            statuses[type] = permissionManager.status(for: type)
        }
        permissionStatuses = statuses
        await loadCompliance()
    }

    public func loadCompliance() async {
        guard let complianceService else { return }
        complianceErrorMessage = nil
        do {
            compliance = try await complianceService.fetchComplianceConfig()
        } catch {
            complianceErrorMessage = error.localizedDescription
        }
    }

    public func statusLabel(for type: PermissionType) -> String {
        switch permissionStatuses[type] ?? .notDetermined {
        case .notDetermined:
            return L10n.string("settings.permission.not_determined")
        case .denied:
            return L10n.string("settings.permission.denied")
        case .authorized:
            return L10n.string("settings.permission.authorized")
        case .restricted:
            return L10n.string("settings.permission.restricted")
        }
    }

    public func needsSettingsPrompt(for type: PermissionType) -> Bool {
        permissionStatuses[type]?.isDenied == true
    }
}
