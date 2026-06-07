import Foundation

/// 应用启动时注册 Bugly + Sentry 双采集（adapter 按编译条件路由 Live/Stub）。
public enum CrashReportingBootstrap {
    public static func configureIfNeeded(bundle: Bundle = .main) {
        let configuration = CrashReportingConfiguration(bundle: bundle)
        guard configuration.isEnabled else { return }

        // 第三方 SDK 异步注册，对齐 design-ios §14 冷启动并发
        DispatchQueue.global(qos: .utility).async {
            SentryReporting.bootstrap(configuration: configuration)
            BuglyReporting.bootstrap(configuration: configuration)
        }
    }
}
