import Foundation

final class MockRegistry: @unchecked Sendable {
    static let shared = MockRegistry()
    private let lock = NSLock()
    private var handler: MockRequestHandler?
    private var requestLog: [URLRequest] = []

    func register(handler: @escaping MockRequestHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        requestLog.removeAll()
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        requestLog.removeAll()
    }

    func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requestLog
    }

    func handle(_ request: URLRequest) -> MockResponse? {
        lock.lock()
        requestLog.append(request)
        let currentHandler = handler
        lock.unlock()
        return currentHandler?(request)
    }
}

public struct MockResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public init(statusCode: Int, headers: [String: String] = [:], json: String) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = Data(json.utf8)
    }
}

public typealias MockRequestHandler = @Sendable (URLRequest) -> MockResponse?

public enum MockURLProtocol {
    public static func register(handler: @escaping MockRequestHandler) {
        MockRegistry.shared.register(handler: handler)
    }

    public static func reset() {
        MockRegistry.shared.reset()
    }

    public static func recordedRequests() -> [URLRequest] {
        MockRegistry.shared.recordedRequests()
    }

    public static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocolHandler.self]
        return configuration
    }

    public static func makeSession() -> URLSession {
        URLSession(configuration: makeSessionConfiguration())
    }
}

private final class MockURLProtocolHandler: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let response = MockRegistry.shared.handle(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

public enum MockServer {
    public static func loginSuccessJSON(
        userId: String = "usr_test_001",
        accessToken: String = "access_token_initial",
        refreshToken: String = "refresh_token_initial"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_login_001",
          "data": {
            "userId": "\(userId)",
            "isNewUser": true,
            "accessToken": "\(accessToken)",
            "accessTokenExpiresIn": 3600,
            "refreshToken": "\(refreshToken)",
            "refreshTokenExpiresIn": 2592000,
            "profile": {
              "nickname": "测试用户",
              "avatarUrl": null,
              "region": "cn",
              "consents": { "childData": false }
            }
          }
        }
        """
    }

    public static func refreshSuccessJSON(
        accessToken: String = "access_token_refreshed",
        refreshToken: String = "refresh_token_rotated"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_refresh_001",
          "data": {
            "accessToken": "\(accessToken)",
            "accessTokenExpiresIn": 3600,
            "refreshToken": "\(refreshToken)",
            "refreshTokenExpiresIn": 2592000
          }
        }
        """
    }

    public static func tokenExpiredJSON() -> String {
        """
        {
          "code": "AUTH_TOKEN_EXPIRED",
          "message": "access token expired",
          "requestId": "req_expired_001"
        }
        """
    }

    public static func meSuccessJSON(
        userId: String = "usr_test_001",
        nickname: String = "测试用户",
        childDataConsent: Bool = false
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_me_001",
          "data": {
            "userId": "\(userId)",
            "nickname": "\(nickname)",
            "avatarUrl": null,
            "region": "cn",
            "consents": { "childData": \(childDataConsent) }
          }
        }
        """
    }

    public static func childDataConsentStatusJSON(
        currentVersion: String = "child_consent_v1",
        agreed: Bool = false,
        requiresConsent: Bool = true,
        agreedVersion: String? = nil
    ) -> String {
        let agreedVersionField = agreedVersion.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_consent_status_001",
          "data": {
            "currentVersion": "\(currentVersion)",
            "agreedVersion": \(agreedVersionField),
            "agreed": \(agreed),
            "requiresConsent": \(requiresConsent)
          }
        }
        """
    }

    public static func childDataConsentSuccessJSON(version: String = "child_consent_v1") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_consent_001",
          "data": {
            "version": "\(version)",
            "agreedAt": "2026-06-06T10:00:00Z"
          }
        }
        """
    }

    public static func emptySuccessJSON(requestId: String = "req_ok_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "\(requestId)"
        }
        """
    }

    public static func deletionSuccessJSON() -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_delete_001",
          "data": {
            "requestedAt": "2026-06-06T10:00:00Z",
            "scheduledAt": "2026-06-13T10:00:00Z",
            "revokeBefore": "2026-06-13T10:00:00Z"
          }
        }
        """
    }

    public static func babySuccessJSON(
        babyId: String = "bb_test001",
        familyId: String = "fam_test001",
        name: String = "豆豆",
        birthday: String = "2024-01-15",
        gender: String = "male",
        birthTime: String? = "08:30",
        avatarUrl: String? = nil
    ) -> String {
        let birthTimeField = birthTime.map { "\"birthTime\": \"\($0)\"," } ?? ""
        let avatarField: String
        if let avatarUrl {
            avatarField = "\"avatarUrl\": \"\(avatarUrl)\""
        } else {
            avatarField = "\"avatarUrl\": null"
        }
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_baby_001",
          "data": {
            "babyId": "\(babyId)",
            "familyId": "\(familyId)",
            "name": "\(name)",
            "birthday": "\(birthday)",
            "gender": "\(gender)",
            \(birthTimeField)
            "timezone": "Asia/Shanghai",
            \(avatarField)
          }
        }
        """
    }

    public static func babyListSuccessJSON(
        babyId: String = "bb_test001",
        name: String = "豆豆"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_baby_list_001",
          "data": {
            "items": [
              {
                "babyId": "\(babyId)",
                "name": "\(name)",
                "birthday": "2024-01-15",
                "gender": "male"
              }
            ]
          }
        }
        """
    }

    public static func babyAvatarSuccessJSON(
        babyId: String = "bb_test001",
        avatarUrl: String = "https://cdn.example.com/avatar/bb_test001.jpg"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_baby_avatar_001",
          "data": {
            "babyId": "\(babyId)",
            "avatarUrl": "\(avatarUrl)"
          }
        }
        """
    }

    public static func uploadInitSuccessJSON(
        uploadId: String = "upl_test_001",
        clientRef: String = "photo-ref-001",
        objectKey: String = "ai-tmp/usr_test/photo.heic",
        uploadUrl: String = "http://127.0.0.1/mock-oss/put/photo.heic",
        includeSTS: Bool = true
    ) -> String {
        let stsBlock: String
        if includeSTS {
            stsBlock = """
            "sts": {
              "accessKeyId": "STS.mock.usr_test",
              "accessKeySecret": "mock-secret-cn",
              "securityToken": "mock-token-usr_test",
              "expiration": "2026-06-06T12:00:00Z"
            },
            """
        } else {
            stsBlock = ""
        }
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_upload_init_001",
          "data": {
            "uploadId": "\(uploadId)",
            \(stsBlock)
            "items": [
              {
                "clientRef": "\(clientRef)",
                "objectKey": "\(objectKey)",
                "uploadUrl": "\(uploadUrl)",
                "method": "PUT",
                "headers": { "Content-Type": "image/heic" },
                "expiresIn": 600
              }
            ]
          }
        }
        """
    }

    public static func uploadCompleteSuccessJSON(
        uploadId: String = "upl_test_001",
        clientRef: String = "photo-ref-001",
        objectKey: String = "ai-tmp/usr_test/photo.heic"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_upload_complete_001",
          "data": {
            "uploadId": "\(uploadId)",
            "status": "completed",
            "items": [
              {
                "clientRef": "\(clientRef)",
                "objectKey": "\(objectKey)",
                "sha256": "abc123",
                "size": 1024,
                "mime": "image/heic"
              }
            ]
          }
        }
        """
    }

    public static func babyDeleteSuccessJSON(babyId: String = "bb_test001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_baby_delete_001",
          "data": {
            "babyId": "\(babyId)"
          }
        }
        """
    }

    public static func captionGenerateSuccessJSON(
        remainingToday: Int = 49,
        candidates: [CaptionCandidate] = [
            CaptionCandidate(
                text: "豆豆 · 第 312 天 · 化身吉卜力小主角 🌿",
                hashtags: ["#宝宝成长", "#吉卜力"]
            ),
            CaptionCandidate(
                text: "杭州的小晴天里，第 312 天的豆豆 ✨",
                hashtags: ["#日常打卡"]
            ),
            CaptionCandidate(
                text: "AI 帮我画了一个童话版的豆豆 💫",
                hashtags: ["#AI共创"]
            ),
        ]
    ) -> String {
        let candidateJSON = candidates.map { candidate in
            let tags = candidate.hashtags.map { "\"\($0)\"" }.joined(separator: ", ")
            return """
            { "text": "\(candidate.text)", "hashtags": [\(tags)] }
            """
        }.joined(separator: ",\n")
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_caption_generate_001",
          "data": {
            "candidates": [
            \(candidateJSON)
            ],
            "remainingToday": \(remainingToday)
          }
        }
        """
    }

    public static func captionDailyLimitJSON() -> String {
        """
        {
          "code": "CAPTION_DAILY_LIMIT",
          "message": "daily caption generation limit exceeded",
          "requestId": "req_caption_limit_001"
        }
        """
    }

    public static func familyFeedListJSON(
        items: String = """
              {
                "postId": "pst_feed_001",
                "familyId": "fam_test001",
                "ownerUserId": "usr_test001",
                "babyIds": ["bb_test001"],
                "caption": "豆豆 · 第 10 天 · 吉卜力风",
                "visibility": "family",
                "status": "published",
                "createdAt": "2026-06-06T10:00:00Z",
                "items": [
                  {
                    "itemId": "pi_001",
                    "kind": "image",
                    "objectKey": "family/fam_test001/post/1.heic",
                    "width": 1024,
                    "height": 1024,
                    "deepSynth": true
                  }
                ]
              }
        """,
        nextCursor: String? = nil,
        cacheTtlSeconds: Int = 60
    ) -> String {
        let cursorField: String
        if let nextCursor, !nextCursor.isEmpty {
            cursorField = """
            "nextCursor": "\(nextCursor)",
            """
        } else {
            cursorField = ""
        }

        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_feed_list_001",
          "data": {
            "items": [
            \(items)
            ],
            \(cursorField)
            "cacheTtlSeconds": \(cacheTtlSeconds)
          }
        }
        """
    }

    public static func postCreateSuccessJSON(
        postId: String = "pst_test001",
        status: String = "published",
        createdAt: String = "2026-06-06T10:00:00Z"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_post_create_001",
          "data": {
            "postId": "\(postId)",
            "status": "\(status)",
            "createdAt": "\(createdAt)"
          }
        }
        """
    }

    public static func postDeleteSuccessJSON(
        postId: String = "pst_test001",
        status: String = "removed",
        deletedAt: String = "2026-06-06T11:00:00Z"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_post_delete_001",
          "data": {
            "postId": "\(postId)",
            "status": "\(status)",
            "deletedAt": "\(deletedAt)"
          }
        }
        """
    }

    public static func familyListJSON() -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_families_001",
          "data": {
            "items": [
              {
                "familyId": "fam_test_001",
                "name": "豆豆的家",
                "role": "admin"
              }
            ]
          }
        }
        """
    }

    public static func familyDetailJSON(familyId: String = "fam_test_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_family_detail_001",
          "data": {
            "familyId": "\(familyId)",
            "name": "豆豆的家",
            "role": "admin",
            "members": [
              {
                "userId": "usr_admin",
                "role": "admin",
                "nickname": "豆豆妈",
                "joinedAt": "2026-06-01T10:00:00Z"
              },
              {
                "userId": "usr_member",
                "role": "family",
                "nickname": "外婆",
                "joinedAt": "2026-06-05T10:00:00Z"
              }
            ],
            "babies": []
          }
        }
        """
    }

    public static func createFamilyJSON(name: String = "新家") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_create_family_001",
          "data": {
            "familyId": "fam_new_001",
            "name": "\(name)",
            "role": "admin"
          }
        }
        """
    }

    public static func invitationJSON(
        code: String = "123456",
        sig: String = "abc123"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_invite_001",
          "data": {
            "code": "\(code)",
            "expireAt": "2026-06-07T10:00:00Z",
            "maxUses": 5,
            "usedCount": 0,
            "qrPayload": {
              "scheme": "baobao://invite",
              "code": "\(code)",
              "sig": "\(sig)"
            }
          }
        }
        """
    }

    public static func joinFamilyJSON(familyId: String = "fam_test_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_join_001",
          "data": {
            "familyId": "\(familyId)",
            "role": "family",
            "joinedAt": "2026-06-06T10:00:00Z"
          }
        }
        """
    }

    public static func transferAdminJSON(
        familyId: String = "fam_test_001",
        previousAdminUserId: String = "usr_admin",
        newAdminUserId: String = "usr_member"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_transfer_001",
          "data": {
            "familyId": "\(familyId)",
            "previousAdminUserId": "\(previousAdminUserId)",
            "newAdminUserId": "\(newAdminUserId)",
            "transferredAt": "2026-06-06T10:00:00Z"
          }
        }
        """
    }

    public static func takeoverVoteJSON(
        voteId: String = "tov_test_001",
        status: String = "voting",
        initiatorUserId: String = "usr_member",
        eligibleVoters: Int = 3,
        approveCount: Int = 1,
        rejectCount: Int = 0,
        requiredApprovals: Int = 2,
        objectionEndsAt: String? = nil
    ) -> String {
        let objectionField = objectionEndsAt.map { "\"objectionEndsAt\": \"\($0)\"" }
        let trailingField = objectionField.map { ",\n            \($0)" } ?? ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_takeover_001",
          "data": {
            "voteId": "\(voteId)",
            "status": "\(status)",
            "initiatorUserId": "\(initiatorUserId)",
            "eligibleVoters": \(eligibleVoters),
            "approveCount": \(approveCount),
            "rejectCount": \(rejectCount),
            "requiredApprovals": \(requiredApprovals)\(trailingField)
          }
        }
        """
    }

    public static func subscriptionMeJSON(
        active: Bool = true,
        state: String = "active",
        sku: String = "com.baobao.sub.monthly",
        cacheTtlSeconds: Int = 600,
        removeAds: Bool = true,
        brandWatermarkRemovable: Bool = true
    ) -> String {
        let activeFields = active
            ? """
            "sku": "\(sku)",
            "periodStart": "2026-06-01T00:00:00Z",
            "periodEnd": "2026-07-01T00:00:00Z",
            "autoRenew": true,
            "subscriptionId": "sub_test_001",
            """
            : ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_subscription_me_001",
          "data": {
            "active": \(active),
            "state": "\(state)",
            \(activeFields)
            "cacheTtlSeconds": \(cacheTtlSeconds),
            "entitlements": {
              "removeAds": \(removeAds),
              "brandWatermarkRemovable": \(brandWatermarkRemovable),
              "allFilters": \(active),
              "annualReviewRegen": \(active)
            }
          }
        }
        """
    }

    public static func subscriptionIAPVerifyJSON(
        state: String = "active",
        sku: String = "com.baobao.sub.monthly",
        duplicate: Bool = false
    ) -> String {
        let duplicateField = duplicate ? ", \"duplicate\": true" : ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_subscription_iap_verify_001",
          "data": {
            "subscriptionId": "sub_test_001",
            "state": "\(state)",
            "sku": "\(sku)",
            "periodStart": "2026-06-01T00:00:00Z",
            "periodEnd": "2026-07-01T00:00:00Z",
            "autoRenew": true,
            "entitlements": {
              "removeAds": true,
              "brandWatermarkRemovable": true,
              "allFilters": true,
              "annualReviewRegen": true
            }\(duplicateField)
          }
        }
        """
    }

    public static func subscriptionProductsJSON(region: String = "cn") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_subscription_products_001",
          "data": {
            "region": "\(region)",
            "products": [
              {
                "productId": "com.baobao.sub.monthly",
                "name": "月会员",
                "period": "monthly",
                "priceCny": 18,
                "regions": ["cn", "os"]
              },
              {
                "productId": "com.baobao.sub.yearly",
                "name": "年会员",
                "period": "yearly",
                "priceCny": 128,
                "bonusCredits": 200,
                "regions": ["cn", "os"]
              }
            ]
          }
        }
        """
    }

    public static func creditBalanceJSON(
        balance: Int = 100,
        signInAvailable: Bool = true
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_credit_balance_001",
          "data": {
            "balance": \(balance),
            "signInAvailable": \(signInAvailable)
          }
        }
        """
    }

    public static func creditRatesJSON(
        version: String = "20250606001",
        ghibliCost: Int = 8,
        videoFiveSecondCost: Int = 60
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_credit_rates_001",
          "data": {
            "version": "\(version)",
            "plays": [
              {
                "playId": "ghibli_kid",
                "kind": "image",
                "creditCost": \(ghibliCost)
              },
              {
                "playId": "video_walk",
                "kind": "video",
                "durationTiers": [
                  { "durationSeconds": 5, "creditCost": \(videoFiveSecondCost) },
                  { "durationSeconds": 10, "creditCost": 120 }
                ]
              }
            ]
          }
        }
        """
    }

    public static func creditSignInJSON(
        grantedCredits: Int = 5,
        balanceAfter: Int = 105,
        streak: Int = 1,
        ledgerId: String = "led_signin_001"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_credit_signin_001",
          "data": {
            "grantedCredits": \(grantedCredits),
            "balanceAfter": \(balanceAfter),
            "streak": \(streak),
            "ledgerId": "\(ledgerId)"
          }
        }
        """
    }

    public static func creditSignInDoneJSON() -> String {
        """
        {
          "code": "CREDIT_SIGN_IN_DONE",
          "message": "already signed in today",
          "requestId": "req_credit_signin_dup"
        }
        """
    }

    public static func iapVerifySuccessJSON(
        grantedCredits: Int = 330,
        balanceAfter: Int = 430,
        transactionId: String = "2000000123456789",
        ledgerId: String = "led_test_001",
        duplicate: Bool = false
    ) -> String {
        let duplicateField = duplicate ? ", \"duplicate\": true" : ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_iap_verify_001",
          "data": {
            "grantedCredits": \(grantedCredits),
            "balanceAfter": \(balanceAfter),
            "transactionId": "\(transactionId)",
            "ledgerId": "\(ledgerId)"\(duplicateField)
          }
        }
        """
    }

    public static func adRewardSuccessJSON(
        grantedCredits: Int = 5,
        balanceAfter: Int = 105,
        ledgerId: String = "led_ad_reward_001",
        duplicate: Bool = false
    ) -> String {
        let duplicateField = duplicate ? ", \"duplicate\": true" : ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_ad_reward_001",
          "data": {
            "grantedCredits": \(grantedCredits),
            "balanceAfter": \(balanceAfter),
            "ledgerId": "\(ledgerId)"\(duplicateField)
          }
        }
        """
    }

    public static func creditTransactionsJSON(
        items: [CreditTransactionItem] = [
            CreditTransactionItem(
                id: "txn_001",
                type: "grant",
                amount: 20,
                refKind: "iap",
                refId: "iap_001",
                balanceAfter: 120,
                createdAt: "2026-06-06T08:00:00Z"
            ),
            CreditTransactionItem(
                id: "txn_002",
                type: "consume",
                amount: -8,
                refKind: "ai_task",
                refId: "tsk_001",
                balanceAfter: 112,
                createdAt: "2026-06-06T09:00:00Z"
            ),
        ],
        nextCursor: String? = "cursor_page_2"
    ) -> String {
        let itemJSON = items.map { item in
            let refKind = item.refKind.map { "\"refKind\": \"\($0)\"," } ?? ""
            let refId = item.refId.map { "\"refId\": \"\($0)\"," } ?? ""
            return """
            {
              "id": "\(item.id)",
              "type": "\(item.type)",
              "amount": \(item.amount),
              \(refKind)
              \(refId)
              "balanceAfter": \(item.balanceAfter),
              "createdAt": "\(item.createdAt)"
            }
            """
        }.joined(separator: ",\n")
        let nextCursorField = nextCursor.map { "\"nextCursor\": \"\($0)\"" } ?? ""
        let trailingComma = nextCursor == nil ? "" : ","
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_credit_transactions_001",
          "data": {
            "items": [
            \(itemJSON)
            ]\(trailingComma)
            \(nextCursorField)
          }
        }
        """
    }

    public static func aiTaskCreatedJSON(
        taskId: String = "tsk_test_001",
        state: String = "credit_held",
        costCredits: Int = 8,
        balanceAfter: Int = 92,
        estimatedSeconds: Int = 18
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_ai_task_create_001",
          "data": {
            "taskId": "\(taskId)",
            "state": "\(state)",
            "costCredits": \(costCredits),
            "balanceAfter": \(balanceAfter),
            "estimatedSeconds": \(estimatedSeconds)
          }
        }
        """
    }

    public static func aiTaskDetailJSON(
        taskId: String = "tsk_test_001",
        state: String = "running",
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil,
        costCredits: Int = 8,
        balanceAfter: Int = 92,
        failureReason: String? = nil
    ) -> String {
        let resultField = resultUrl.map { "\"resultUrl\": \"\($0)\"," } ?? ""
        let thumbField = thumbnailUrl.map { "\"thumbnailUrl\": \"\($0)\"," } ?? ""
        let failureField = failureReason.map { "\"failureReason\": \"\($0)\"," } ?? ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_ai_task_get_001",
          "data": {
            "taskId": "\(taskId)",
            "state": "\(state)",
            \(resultField)
            \(thumbField)
            "costCredits": \(costCredits),
            "balanceAfter": \(balanceAfter)
            \(failureField.isEmpty ? "" : failureField)
          }
        }
        """
    }

    public static func aiTaskAppealJSON(
        taskId: String = "tsk_test_001",
        state: String = "appealed",
        appealId: String = "apl_test_001"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_ai_task_appeal_001",
          "data": {
            "taskId": "\(taskId)",
            "state": "\(state)",
            "appealId": "\(appealId)"
          }
        }
        """
    }

    public static func aiInsufficientCreditJSON() -> String {
        """
        {
          "code": "AI_INSUFFICIENT_CREDIT",
          "message": "积分不足",
          "requestId": "req_ai_task_create_002"
        }
        """
    }

    public static func registerDeviceJSON(
        deviceId: String = "dev_test_001",
        apnsToken: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
        region: String = "cn"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_notif_register_001",
          "data": {
            "deviceId": "\(deviceId)",
            "apnsToken": "\(apnsToken)",
            "region": "\(region)"
          }
        }
        """
    }

    public static func notificationListJSON(
        items: [NotificationItem] = [
            NotificationItem(
                id: "ntf_001",
                category: .familyActivity,
                payload: NotificationPayload(
                    title: "外婆点赞了照片",
                    body: "豆豆的第 100 天",
                    deepLink: "baobao://feed/post_001"
                ),
                createdAt: "2026-06-06T08:00:00Z"
            ),
            NotificationItem(
                id: "ntf_002",
                category: .aiDone,
                payload: NotificationPayload(
                    title: "AI 任务完成",
                    body: "宫崎骏风照片已生成",
                    deepLink: "baobao://ai/task/tsk_001"
                ),
                readAt: "2026-06-06T09:00:00Z",
                createdAt: "2026-06-06T07:30:00Z"
            ),
        ],
        nextCursor: String? = nil,
        unreadCount: Int = 1
    ) -> String {
        let itemJSON = items.map { item in
            let readAtField = item.readAt.map { "\"readAt\": \"\($0)\"," } ?? ""
            let deepLink = item.payload.deepLink.map { "\"deepLink\": \"\($0)\"," } ?? ""
            let imageUrl = item.payload.imageUrl.map { "\"imageUrl\": \"\($0)\"," } ?? ""
            let title = item.payload.title.map { "\"title\": \"\($0)\"," } ?? ""
            let body = item.payload.body.map { "\"body\": \"\($0)\"," } ?? ""
            return """
            {
              "id": "\(item.id)",
              "category": "\(item.category.rawValue)",
              "payload": {
                \(title)
                \(body)
                \(deepLink)
                \(imageUrl)
                "placeholder": true
              },
              \(readAtField)
              "createdAt": "\(item.createdAt)"
            }
            """
        }.joined(separator: ",\n")
        let nextCursorField = nextCursor.map { "\"nextCursor\": \"\($0)\"," } ?? ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_notif_list_001",
          "data": {
            "items": [
            \(itemJSON)
            ],
            \(nextCursorField)
            "unreadCount": \(unreadCount)
          }
        }
        """
    }

    public static func markNotificationsReadJSON(
        markedCount: Int = 1,
        unreadCount: Int = 0
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_notif_mark_read_001",
          "data": {
            "markedCount": \(markedCount),
            "unreadCount": \(unreadCount)
          }
        }
        """
    }

    public static func notificationSubscriptionsJSON(
        subscriptions: [NotificationSubscriptionItem] = [
            NotificationSubscriptionItem(category: .milestone, enabled: true),
            NotificationSubscriptionItem(category: .familyActivity, enabled: true),
            NotificationSubscriptionItem(category: .aiDone, enabled: true),
            NotificationSubscriptionItem(category: .credit, enabled: true),
            NotificationSubscriptionItem(category: .system, enabled: false),
        ]
    ) -> String {
        let subscriptionJSON = subscriptions.map { item in
            """
            { "category": "\(item.category.rawValue)", "enabled": \(item.enabled) }
            """
        }.joined(separator: ",\n")
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_notif_subscriptions_001",
          "data": {
            "subscriptions": [
            \(subscriptionJSON)
            ]
          }
        }
        """
    }

    public static func aiPlaysCatalogJSON(
        region: String = "cn",
        includeUnavailable: Bool = false
    ) -> String {
        let unavailableBlock: String
        if includeUnavailable {
            unavailableBlock = """
            ,
              {
                "id": "gpt_portrait",
                "name": "高质量写真",
                "description": "1024px 输出",
                "kind": "image",
                "creditCost": 15,
                "available": false
              }
            """
        } else {
            unavailableBlock = ""
        }
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_ai_plays_001",
          "data": {
            "version": "20250606001",
            "region": "\(region)",
            "ttlSeconds": 300,
            "plays": [
              {
                "id": "ghibli_kid",
                "name": "宫崎骏风",
                "description": "风格化图像，720p 输出",
                "kind": "image",
                "creditCost": 8,
                "available": true
              },
              {
                "id": "seedream_style",
                "name": "Seedream 风格化",
                "description": "国内风格化图像",
                "kind": "image",
                "creditCost": 8,
                "available": true
              },
              {
                "id": "video_walk",
                "name": "图生视频",
                "description": "宝宝学步等场景短视频",
                "kind": "video",
                "available": true,
                "durationTiers": [
                  { "durationSeconds": 5, "creditCost": 60 },
                  { "durationSeconds": 10, "creditCost": 120 }
                ]
              }
              \(unavailableBlock)
            ]
          }
        }
        """
    }

    /// P1 XCUITest / UI 回归：登录 → 引导（家庭+宝宝+同意）→ 注销
    public static func backupProviderJSON(
        id: String = "bkp_test_001",
        kind: String = "baidu_pan",
        status: String = "active",
        providerAccountId: String? = "baidu-user-1",
        expiresAt: String? = "2026-07-01T00:00:00Z"
    ) -> String {
        let accountField = providerAccountId.map { "\"providerAccountId\": \"\($0)\"," } ?? ""
        let expiresField = expiresAt.map { "\"expiresAt\": \"\($0)\"," } ?? ""
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_backup_bind",
          "data": {
            "id": "\(id)",
            "kind": "\(kind)",
            "status": "\(status)",
            \(accountField)
            \(expiresField)
            "metadata": { "scope": "basic" },
            "createdAt": "2026-06-06T08:00:00Z",
            "updatedAt": "2026-06-06T08:00:00Z"
          }
        }
        """
    }

    public static func backupProviderListJSON(
        items: [(id: String, kind: String)] = [("bkp_test_001", "baidu_pan")]
    ) -> String {
        let rendered = items.map { item in
            """
            {
              "id": "\(item.id)",
              "kind": "\(item.kind)",
              "status": "active",
              "metadata": {},
              "createdAt": "2026-06-06T08:00:00Z",
              "updatedAt": "2026-06-06T08:00:00Z"
            }
            """
        }.joined(separator: ",")
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_backup_list",
          "data": {
            "items": [\(rendered)]
          }
        }
        """
    }

    public static func backupUnbindJSON(id: String = "bkp_test_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_backup_unbind",
          "data": { "id": "\(id)" }
        }
        """
    }

    public static func backupStatusJSON(
        lastSuccessAt: String? = nil,
        lastAttemptAt: String? = "2026-06-06T08:00:00Z",
        failureCount: Int = 0,
        lastErrorCode: String? = nil
    ) -> String {
        var fields: [String] = []
        if let lastSuccessAt {
            fields.append("\"lastSuccessAt\": \"\(lastSuccessAt)\"")
        }
        if let lastAttemptAt {
            fields.append("\"lastAttemptAt\": \"\(lastAttemptAt)\"")
        }
        fields.append("\"failureCount\": \(failureCount)")
        if let lastErrorCode {
            fields.append("\"lastErrorCode\": \"\(lastErrorCode)\"")
        } else {
            fields.append("\"lastErrorCode\": null")
        }
        let body = fields.joined(separator: ",\n            ")
        return """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_backup_status",
          "data": {
            \(body)
          }
        }
        """
    }

    public static func p1E2EHandler(
        familyId: String = "fam_e2e_001",
        babyId: String = "bb_e2e_001"
    ) -> MockRequestHandler {
        { request in
            guard let path = request.url?.path else { return nil }
            let method = request.httpMethod ?? "GET"

            if method == "POST", path == "/v1/auth/phone/code" {
                return MockResponse(statusCode: 200, json: emptySuccessJSON(requestId: "req_e2e_code"))
            }
            if method == "POST", path == "/v1/auth/phone/login" {
                return MockResponse(statusCode: 200, json: loginSuccessJSON(userId: "usr_e2e_uitest"))
            }
            if method == "GET", path == "/v1/account/me" {
                return MockResponse(statusCode: 200, json: meSuccessJSON(userId: "usr_e2e_uitest", nickname: "E2E用户"))
            }
            if method == "PATCH", path == "/v1/account/me" {
                return MockResponse(statusCode: 200, json: meSuccessJSON(userId: "usr_e2e_uitest", nickname: "E2E用户"))
            }
            if method == "POST", path == "/v1/families" {
                return MockResponse(statusCode: 200, json: createFamilyJSON(name: "E2E家庭"))
            }
            if method == "GET", path == "/v1/account/consents/child-data" {
                return MockResponse(statusCode: 200, json: childDataConsentStatusJSON())
            }
            if method == "POST", path == "/v1/account/consents/child-data" {
                return MockResponse(statusCode: 200, json: childDataConsentSuccessJSON())
            }
            if method == "POST", path.hasSuffix("/babies") {
                return MockResponse(statusCode: 200, json: babySuccessJSON(babyId: babyId, familyId: familyId))
            }
            if method == "POST", path == "/v1/account/logout" {
                return MockResponse(statusCode: 200, json: emptySuccessJSON(requestId: "req_e2e_logout"))
            }
            if method == "DELETE", path == "/v1/account" {
                return MockResponse(statusCode: 200, json: deletionSuccessJSON())
            }
            return nil
        }
    }

    /// P6 XCUITest smoke：备份凭据 + 账号注销（T6.15）
    public static func p6E2EHandler(
        familyId: String = "fam_e2e_001",
        babyId: String = "bb_e2e_001"
    ) -> MockRequestHandler {
        let base = p1E2EHandler(familyId: familyId, babyId: babyId)
        return { request in
            if let baseResponse = base(request) {
                return baseResponse
            }
            guard let path = request.url?.path else { return nil }
            let method = request.httpMethod ?? "GET"

            if method == "POST", path == "/v1/backup/providers" {
                let kind = Self.extractJSONString(from: request, key: "kind") ?? "icloud"
                return MockResponse(
                    statusCode: 200,
                    json: backupProviderJSON(id: "bkp_p6_\(kind)", kind: kind)
                )
            }
            if method == "GET", path == "/v1/backup/providers" {
                return MockResponse(
                    statusCode: 200,
                    json: backupProviderListJSON(items: [("bkp_p6_icloud", "icloud")])
                )
            }
            if method == "DELETE", path.hasPrefix("/v1/backup/providers/") {
                let id = path.split(separator: "/").last.map(String.init) ?? "bkp_p6_001"
                return MockResponse(statusCode: 200, json: backupUnbindJSON(id: id))
            }
            if method == "GET", path == "/v1/backup/status" {
                return MockResponse(statusCode: 200, json: backupStatusJSON(failureCount: 0))
            }
            if method == "POST", path == "/v1/backup/status" {
                return MockResponse(
                    statusCode: 200,
                    json: backupStatusJSON(
                        lastSuccessAt: "2026-06-06T09:00:00Z",
                        failureCount: 0
                    )
                )
            }
            if method == "POST", path == "/v1/account/export" {
                return MockResponse(
                    statusCode: 202,
                    json: """
                    {
                      "code": "OK",
                      "message": "ok",
                      "requestId": "req_p6_export",
                      "data": {
                        "exportId": "exp_p6_001",
                        "status": "queued",
                        "requestedAt": "2026-06-06T10:00:00Z"
                      }
                    }
                    """
                )
            }
            return nil
        }
    }

    private static func extractJSONString(from request: URLRequest, key: String) -> String? {
        guard let body = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let value = json[key] as? String else {
            return nil
        }
        return value
    }
}
