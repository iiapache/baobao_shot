import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 打开系统设置页的抽象，便于单测注入。
public protocol SettingsOpening: Sendable {
    @MainActor func open(_ url: URL) -> Bool
}

/// 默认实现，通过 `UIApplication` 跳转系统设置。
public struct LiveSettingsRouter: SettingsOpening {
    public init() {}

    @MainActor
    public func open(_ url: URL) -> Bool {
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url)
        return true
        #else
        return false
        #endif
    }
}

public extension PermissionManager {
    /// 当权限为 `denied` 时打开系统设置；否则返回 `false`。
    @MainActor
    @discardableResult
    func openSettings(
        for type: PermissionType,
        using router: any SettingsOpening = LiveSettingsRouter()
    ) -> Bool {
        guard let url = settingsURL(for: type) else { return false }
        return router.open(url)
    }
}

/// Feature 层权限流程辅助：查询 → 申请 → 被拒引导设置。
@MainActor
public struct PermissionRouting {
    private let manager: any PermissionManager
    private let router: any SettingsOpening

    public init(
        manager: any PermissionManager,
        router: any SettingsOpening = LiveSettingsRouter()
    ) {
        self.manager = manager
        self.router = router
    }

    public func status(for type: PermissionType) -> PermissionStatus {
        manager.status(for: type)
    }

    /// 未决时发起系统授权弹窗；已决状态直接返回当前值。
    public func ensureAuthorized(_ type: PermissionType) async -> PermissionStatus {
        let current = manager.status(for: type)
        guard current == .notDetermined else { return current }
        return await manager.requestAuthorization(for: type)
    }

    /// 权限是否已被明确拒绝，需要展示设置引导。
    public func needsSettingsPrompt(for type: PermissionType) -> Bool {
        manager.status(for: type).isDenied
    }

    /// 仅在 `denied` 时跳转系统设置。
    @discardableResult
    public func openSettingsIfDenied(_ type: PermissionType) -> Bool {
        guard let url = manager.settingsURL(for: type) else { return false }
        return router.open(url)
    }
}
