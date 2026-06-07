import BabyCameraNetwork
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public protocol APNsTokenProviding: Sendable {
    func currentToken() async -> Data?
}

public protocol DeviceMetadataProviding: Sendable {
    var deviceId: String { get }
    var appVersion: String { get }
    var osVersion: String { get }
    var model: String { get }
}

public struct LiveDeviceMetadataProvider: DeviceMetadataProviding {
    private let regionConfig: RegionConfig

    public init(regionConfig: RegionConfig) {
        self.regionConfig = regionConfig
    }

    public var deviceId: String { regionConfig.deviceId }
    public var appVersion: String { regionConfig.appVersion }

    public var osVersion: String {
        #if canImport(UIKit)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    public var model: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Unknown"
        #endif
    }
}

public enum APNsTokenFormatter {
    public static func hexString(from tokenData: Data) -> String {
        tokenData.map { String(format: "%02x", $0) }.joined()
    }
}
