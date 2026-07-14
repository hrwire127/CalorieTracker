import Foundation
import XCTest
@testable import CalorieTracker

final class NetworkManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testTextEstimateUsesSchemaAndExpectedGrams() async throws {
        StubURLProtocol.setHandler { request in
            XCTAssertTrue(request.url?.absoluteString.contains(GeminiConfiguration.textModel) == true)
            let body = try Self.bodyData(for: request)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertNotNil(json["systemInstruction"])

            let generationConfig = try XCTUnwrap(json["generationConfig"] as? [String: Any])
            XCTAssertEqual(generationConfig["responseMimeType"] as? String, "application/json")
            XCTAssertNotNil(generationConfig["responseSchema"])

            return Self.response(
                for: request,
                statusCode: 200,
                data: Self.validGeminiResponse(estimatedGrams: 999)
            )
        }

        let manager = makeManager()
        let estimate = try await manager.estimateNutrition(foodName: "Chicken breast", grams: 180)

        XCTAssertEqual(estimate.foodName, "Chicken Breast")
        XCTAssertEqual(estimate.estimatedCalories, 297)
        XCTAssertEqual(estimate.estimatedGrams, 180)
        XCTAssertEqual(estimate.estimatedProteinGrams, 56)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testServiceUnavailableRetriesThenSucceeds() async throws {
        StubURLProtocol.setHandler { request in
            if StubURLProtocol.requestCount == 1 {
                return Self.response(
                    for: request,
                    statusCode: 503,
                    data: Self.errorResponse(message: "Temporarily unavailable")
                )
            }

            return Self.response(
                for: request,
                statusCode: 200,
                data: Self.validGeminiResponse()
            )
        }

        let manager = makeManager(retryCount: 2)
        let estimate = try await manager.estimateNutrition(foodName: "Chicken breast", grams: 180)

        XCTAssertEqual(estimate.estimatedCalories, 297)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testLongRateLimitDoesNotRetryImmediately() async throws {
        StubURLProtocol.setHandler { request in
            Self.response(
                for: request,
                statusCode: 429,
                headers: ["Retry-After": "30"],
                data: Self.errorResponse(message: "Resource exhausted")
            )
        }

        let manager = makeManager(retryCount: 2)

        do {
            _ = try await manager.estimateNutrition(foodName: "Rice", grams: 100)
            XCTFail("Expected a rate limit error")
        } catch let error as NetworkManagerError {
            guard case .rateLimited(let retryAfter) = error else {
                return XCTFail("Expected rateLimited, received \(error)")
            }
            XCTAssertEqual(retryAfter, 30)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)

        do {
            _ = try await manager.estimateNutrition(foodName: "Rice", grams: 100)
            XCTFail("Expected the local rate limit cooldown")
        } catch let error as NetworkManagerError {
            guard case .rateLimited = error else {
                return XCTFail("Expected rateLimited, received \(error)")
            }
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testAuthorizationErrorIsNotRetried() async throws {
        StubURLProtocol.setHandler { request in
            Self.response(
                for: request,
                statusCode: 403,
                data: Self.errorResponse(message: "Invalid API key")
            )
        }

        let manager = makeManager(retryCount: 2)

        do {
            _ = try await manager.estimateNutrition(foodName: "Rice", grams: 100)
            XCTFail("Expected an authorization error")
        } catch let error as NetworkManagerError {
            guard case .authorizationFailed = error else {
                return XCTFail("Expected authorizationFailed, received \(error)")
            }
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testRepeatedRequestUsesCache() async throws {
        StubURLProtocol.setHandler { request in
            Self.response(
                for: request,
                statusCode: 200,
                data: Self.validGeminiResponse()
            )
        }

        let manager = makeManager()
        _ = try await manager.estimateNutrition(foodName: "Rice", grams: 100)
        _ = try await manager.estimateNutrition(foodName: "rice", grams: 100)

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testConcurrentIdenticalRequestsAreCoalesced() async throws {
        StubURLProtocol.setHandler { request in
            Thread.sleep(forTimeInterval: 0.05)
            return Self.response(
                for: request,
                statusCode: 200,
                data: Self.validGeminiResponse()
            )
        }

        let manager = makeManager()
        async let first = manager.estimateNutrition(foodName: "Rice", grams: 100)
        async let second = manager.estimateNutrition(foodName: "rice", grams: 100)
        let estimates = try await (first, second)

        XCTAssertEqual(estimates.0.estimatedCalories, 297)
        XCTAssertEqual(estimates.1.estimatedCalories, 297)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testIncompleteEstimateIsRejected() async throws {
        StubURLProtocol.setHandler { request in
            let estimate = #"{"food_name":"Rice","estimated_calories":130,"estimated_grams":100}"#
            return Self.response(
                for: request,
                statusCode: 200,
                data: Self.geminiResponse(containing: estimate)
            )
        }

        let manager = makeManager(retryCount: 0)

        do {
            _ = try await manager.estimateNutrition(foodName: "Rice", grams: 100)
            XCTFail("Expected an invalid estimate error")
        } catch let error as NetworkManagerError {
            guard case .invalidEstimate = error else {
                return XCTFail("Expected invalidEstimate, received \(error)")
            }
        }
    }

    private func makeManager(retryCount: Int = 0) -> NetworkManager {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return NetworkManager(
            session: session,
            retryCount: retryCount,
            cacheLifetime: 60,
            maximumAutomaticRetryDelay: 8,
            apiKeyProvider: { "test-api-key" },
            sleepHandler: { _ in },
            jitterProvider: { 0 }
        )
    }

    private static func validGeminiResponse(estimatedGrams: Int = 180) -> Data {
        let estimate = """
        {"food_name":"Chicken Breast","estimated_calories":297,"estimated_grams":\(estimatedGrams),"estimated_protein_grams":56,"estimated_carb_grams":0,"estimated_fat_grams":6,"health_score":9}
        """
        return geminiResponse(containing: estimate)
    }

    private static func bodyData(for request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeContentData)
            }
            if count == 0 {
                break
            }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    private static func geminiResponse(containing estimate: String) -> Data {
        let payload: [String: Any] = [
            "candidates": [[
                "content": ["parts": [["text": estimate]]],
                "finishReason": "STOP"
            ]]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private static func errorResponse(message: String) -> Data {
        try! JSONSerialization.data(
            withJSONObject: ["error": ["message": message]]
        )
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int,
        headers: [String: String]? = nil,
        data: Data
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        return (response, data)
    }
}

private final class StubURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private static var handler: Handler?
    private static var capturedRequestCount = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequestCount
    }

    static func setHandler(_ handler: @escaping Handler) {
        lock.lock()
        Self.handler = handler
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        capturedRequestCount = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler: Handler?
        Self.lock.lock()
        Self.capturedRequestCount += 1
        handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
