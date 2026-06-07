import XCTest
@testable import BabyCameraNetwork

final class UploadAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testUploadInitSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/uploads/init")
            return MockResponse(statusCode: 200, json: MockServer.uploadInitSuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = UploadAPI(client: client)

        let result = try await api.initialize(
            UploadInitRequest(
                purpose: .aiInput,
                items: [
                    UploadInitItemRequest(
                        clientRef: "photo-ref-001",
                        kind: "image",
                        mime: "image/heic",
                        size: 1024
                    ),
                ]
            )
        )

        XCTAssertEqual(result.uploadId, "upl_test_001")
        XCTAssertEqual(result.sts?.accessKeyId, "STS.mock.usr_test")
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].objectKey, "ai-tmp/usr_test/photo.heic")
    }

    func testUploadCompleteSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/uploads/complete")
            return MockResponse(statusCode: 200, json: MockServer.uploadCompleteSuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = UploadAPI(client: client)

        let result = try await api.complete(UploadCompleteRequest(uploadId: "upl_test_001"))
        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(result.items[0].clientRef, "photo-ref-001")
    }
}

final class OSSRequestSignerTests: XCTestCase {
    func testSignedHeadersContainAuthorizationAndSecurityToken() {
        let credentials = STSCredentials(
            accessKeyId: "STS.test",
            accessKeySecret: "secret",
            securityToken: "token",
            expiration: "2026-06-06T12:00:00Z"
        )
        let headers = OSSRequestSigner.signedHeaders(
            method: "PUT",
            bucket: "baby-camera-cn",
            objectKey: "ai-tmp/user/file.heic",
            contentType: "image/heic",
            credentials: credentials
        )

        XCTAssertTrue(headers["Authorization"]?.hasPrefix("OSS STS.test:") == true)
        XCTAssertEqual(headers["x-oss-security-token"], "token")
        XCTAssertNotNil(headers["Date"])
    }
}

final class UploadServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFullUploadFlowWithMockOSS() async throws {
        var ossPutCount = 0

        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/uploads/init":
                return MockResponse(statusCode: 200, json: MockServer.uploadInitSuccessJSON())
            case "/v1/uploads/complete":
                return MockResponse(statusCode: 200, json: MockServer.uploadCompleteSuccessJSON())
            default:
                if request.httpMethod == "PUT", request.url?.path.contains("mock-oss") == true {
                    ossPutCount += 1
                    return MockResponse(statusCode: 200, body: Data("OK".utf8))
                }
                return nil
            }
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let service = UploadService(client: client, uploadSession: MockURLProtocol.makeSession())

        var progressSnapshots: [UploadProgress] = []
        let payload = Data(repeating: 0xAB, count: 4096)

        let result = try await service.upload(
            purpose: .aiInput,
            items: [
                UploadPayloadItem(
                    clientRef: "photo-ref-001",
                    kind: "image",
                    mime: "image/heic",
                    data: payload
                ),
            ]
        ) { progress in
            progressSnapshots.append(progress)
        }

        XCTAssertEqual(result.uploadId, "upl_test_001")
        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(ossPutCount, 1)
        XCTAssertFalse(progressSnapshots.isEmpty)
        XCTAssertEqual(progressSnapshots.last?.bytesUploaded, Int64(payload.count))
    }

    func testUploadRetriesOnOSSFailure() async throws {
        var ossAttempts = 0

        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/uploads/init":
                return MockResponse(statusCode: 200, json: MockServer.uploadInitSuccessJSON())
            case "/v1/uploads/complete":
                return MockResponse(statusCode: 200, json: MockServer.uploadCompleteSuccessJSON())
            default:
                if request.httpMethod == "PUT", request.url?.path.contains("mock-oss") == true {
                    ossAttempts += 1
                    if ossAttempts < 2 {
                        return MockResponse(statusCode: 503, body: Data("fail".utf8))
                    }
                    return MockResponse(statusCode: 200, body: Data("OK".utf8))
                }
                return nil
            }
        }

        let config = UploadConfiguration(maxRetries: 3, retryBaseDelay: 0.01)
        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let service = UploadService(
            client: client,
            uploadSession: MockURLProtocol.makeSession(),
            configuration: config
        )

        let result = try await service.upload(
            purpose: .aiInput,
            items: [
                UploadPayloadItem(
                    clientRef: "photo-ref-001",
                    kind: "image",
                    mime: "image/heic",
                    data: Data([0x01, 0x02])
                ),
            ]
        )

        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(ossAttempts, 2)
    }

    func testUploadExhaustsRetries() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/uploads/init":
                return MockResponse(statusCode: 200, json: MockServer.uploadInitSuccessJSON())
            default:
                if request.httpMethod == "PUT", request.url?.path.contains("mock-oss") == true {
                    return MockResponse(statusCode: 500, body: Data("fail".utf8))
                }
                return nil
            }
        }

        let config = UploadConfiguration(maxRetries: 2, retryBaseDelay: 0.01)
        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let service = UploadService(
            client: client,
            uploadSession: MockURLProtocol.makeSession(),
            configuration: config
        )

        do {
            _ = try await service.upload(
                purpose: .aiInput,
                items: [
                    UploadPayloadItem(
                        clientRef: "photo-ref-001",
                        kind: "image",
                        mime: "image/heic",
                        data: Data([0x01])
                    ),
                ]
            )
            XCTFail("expected UploadError.exhaustedRetries")
        } catch let error as UploadError {
            XCTAssertEqual(error, .exhaustedRetries(lastStatusCode: 500))
        }
    }

    func testMultipartUploadWithResume() async throws {
        let bucket = "baby-camera-cn"
        let objectKey = "ai-tmp/user/large.heic"
        let uploadUrl = "https://oss-cn-hangzhou.aliyuncs.com/\(bucket)/\(objectKey)"

        var initiateCount = 0
        var partUploadAttempts: [Int: Int] = [:]
        var completeCount = 0
        let ossUploadId = "oss-multipart-id-001"

        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/uploads/init":
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.uploadInitSuccessJSON(
                        objectKey: objectKey,
                        uploadUrl: uploadUrl
                    )
                )
            case "/v1/uploads/complete":
                return MockResponse(statusCode: 200, json: MockServer.uploadCompleteSuccessJSON())
            default:
                guard let url = request.url else { return nil }
                let path = url.path

                if request.httpMethod == "POST", url.query?.contains("uploads") == true {
                    initiateCount += 1
                    let xml = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <InitiateMultipartUploadResult>
                      <UploadId>\(ossUploadId)</UploadId>
                    </InitiateMultipartUploadResult>
                    """
                    return MockResponse(statusCode: 200, body: Data(xml.utf8))
                }

                if request.httpMethod == "PUT",
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   components.queryItems?.contains(where: { $0.name == "partNumber" }) == true {
                    let partNumber = Int(components.queryItems?.first(where: { $0.name == "partNumber" })?.value ?? "0") ?? 0
                    partUploadAttempts[partNumber, default: 0] += 1
                    // 第一分片首次失败，触发重试
                    if partNumber == 1, partUploadAttempts[partNumber] == 1 {
                        return MockResponse(statusCode: 503, body: Data("fail".utf8))
                    }
                    return MockResponse(
                        statusCode: 200,
                        headers: ["ETag": "\"etag-part-\(partNumber)\""],
                        body: Data()
                    )
                }

                if request.httpMethod == "POST",
                   path.hasSuffix(objectKey),
                   url.query?.contains("uploadId=\(ossUploadId)") == true {
                    completeCount += 1
                    return MockResponse(statusCode: 200, body: Data("<Complete>OK</Complete>".utf8))
                }

                return nil
            }
        }

        let chunkSize = 1024
        let config = UploadConfiguration(
            chunkSize: chunkSize,
            multipartThreshold: 512,
            maxRetries: 3,
            retryBaseDelay: 0.01
        )
        let session = MockURLProtocol.makeSession()
        let client = makeAuthenticatedClient(session: session)
        let service = UploadService(
            client: client,
            uploadSession: session,
            configuration: config
        )

        let payload = Data(repeating: 0xCD, count: chunkSize * 2 + 100)
        var lastProgress: UploadProgress?

        let result = try await service.upload(
            purpose: .aiInput,
            items: [
                UploadPayloadItem(
                    clientRef: "photo-ref-001",
                    kind: "image",
                    mime: "image/heic",
                    data: payload
                ),
            ]
        ) { progress in
            lastProgress = progress
        }

        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(initiateCount, 1)
        XCTAssertEqual(completeCount, 1)
        XCTAssertEqual(partUploadAttempts[1], 2, "part 1 should retry once")
        XCTAssertEqual(partUploadAttempts[2], 1)
        XCTAssertEqual(partUploadAttempts[3], 1)
        XCTAssertEqual(lastProgress?.bytesUploaded, Int64(payload.count))
    }
}
