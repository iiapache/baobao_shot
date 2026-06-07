import BabyCameraNetwork
import Foundation

public protocol FeedWebSocketConnecting: Sendable {
    func connect(accessToken: String)
    func disconnect()
    func subscribe(familyIds: [String]) async throws
    var events: AsyncStream<FeedEngagementRemoteEvent> { get }
    var connectionStates: AsyncStream<FeedWebSocketConnectionState> { get }
}

extension FeedWebSocketClient: FeedWebSocketConnecting {}
