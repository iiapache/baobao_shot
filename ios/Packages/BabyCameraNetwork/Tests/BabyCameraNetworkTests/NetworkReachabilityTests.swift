import XCTest
@testable import BabyCameraNetwork

@MainActor
final class NetworkReachabilityTests: XCTestCase {
    func testInitialStateIsOnline() {
        let reachability = NetworkReachability()
        XCTAssertTrue(reachability.isOnline)
    }

    func testStartStopDoesNotCrash() {
        let reachability = NetworkReachability()
        reachability.start()
        reachability.stop()
        reachability.start()
        reachability.stop()
    }

    func testReconnectHandlerCanBeRegisteredAndRemoved() {
        let reachability = NetworkReachability()
        var fired = false
        let id = reachability.onReconnect {
            fired = true
        }
        reachability.removeReconnectHandler(id)
        XCTAssertFalse(fired)
    }
}
