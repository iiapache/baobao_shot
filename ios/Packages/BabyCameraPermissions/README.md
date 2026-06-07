# BabyCameraPermissions

相机 / 相册 / 通知 / 位置（使用时）四类系统权限的统一封装（T2.1）。

```swift
let manager = DefaultPermissionManager()
let status = await manager.requestAuthorization(for: .camera)
if status.isDenied, let url = manager.settingsURL(for: .camera) {
    // 或 PermissionPromptView / PermissionRouting.openSettingsIfDenied
}
```

启动时建议调用 `await manager.refreshNotificationStatus()` 同步通知权限缓存。
