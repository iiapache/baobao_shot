import Foundation

/// UI 测试启动参数解析（T2.22）。
enum UITestLaunchConfiguration {
    static let uiTestingKey = "-UITesting"
    static let p2E2EKey = "-P2E2E"
    static let p6E2EKey = "-P6E2E"
    static let offlineModeKey = "-OfflineMode"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingKey)
    }

    static var isP2E2EMode: Bool {
        ProcessInfo.processInfo.arguments.contains(p2E2EKey)
    }

    static var isP6E2EMode: Bool {
        ProcessInfo.processInfo.arguments.contains(p6E2EKey)
    }

    static var isOfflineMode: Bool {
        ProcessInfo.processInfo.arguments.contains(offlineModeKey)
    }
}
