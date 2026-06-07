/// BabyCameraPermissions — 相机 / 相册 / 通知 / 位置授权统一封装（T2.1）
///
/// 用法：注入 `DefaultPermissionManager`，通过 `requestAuthorization(for:)` 申请权限；
/// 被拒时用 `settingsURL(for:)` / `openSettings(for:)` 或 `PermissionPromptView` 引导用户前往系统设置。
/// Feature 层可用 `PermissionRouting` 封装「查询 → 申请 → 引导设置」流程。
public enum BabyCameraPermissions {
    public static let version = "0.1.0"
}
