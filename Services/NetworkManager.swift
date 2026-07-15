import CryptoKit
import Foundation

protocol NutritionEstimating: AnyObject {
    func estimateCalories(
        fromBase64Image base64Image: String,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate

    func estimateNutrition(
        foodName: String,
        grams: Int,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate
}

extension NutritionEstimating {
    func estimateCalories(fromBase64Image base64Image: String) async throws -> NutritionEstimate {
        try await estimateCalories(fromBase64Image: base64Image, progress: nil)
    }

    func estimateNutrition(foodName: String, grams: Int) async throws -> NutritionEstimate {
        try await estimateNutrition(foodName: foodName, grams: grams, progress: nil)
    }
}

actor NetworkManager: NutritionEstimating {
    static let shared = NetworkManager()

    typealias SleepHandler = (TimeInterval) async throws -> Void

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let apiKeyProvider: () -> String
    private let sleepHandler: SleepHandler
    private let nowProvider: () -> Date
    private let jitterProvider: () -> TimeInterval
    private let retryCount: Int
    private let rateLimitRetryCount: Int
    private let cacheLifetime: TimeInterval
    private let maximumAutomaticRetryDelay: TimeInterval
    private let minimumRateLimitRetryDelay: TimeInterval
    private let requestGate = AIRequestGate()

    private var cache: [RequestKey: CacheEntry] = [:]
    private var inFlightRequests: [RequestKey: Task<NutritionEstimate, Error>] = [:]
    private var rateLimitedUntil: Date?

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        retryCount: Int = 1,
        rateLimitRetryCount: Int = 3,
        cacheLifetime: TimeInterval = 15 * 60,
        maximumAutomaticRetryDelay: TimeInterval = 180,
        minimumRateLimitRetryDelay: TimeInterval = 30,
        apiKeyProvider: @escaping () -> String = { GeminiConfiguration.apiKey },
        sleepHandler: @escaping SleepHandler = NetworkManager.defaultSleep,
        nowProvider: @escaping () -> Date = Date.init,
        jitterProvider: @escaping () -> TimeInterval = { Double.random(in: 0...0.25) }
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.retryCount = max(retryCount, 0)
        self.rateLimitRetryCount = max(rateLimitRetryCount, 0)
        self.cacheLifetime = max(cacheLifetime, 0)
        self.maximumAutomaticRetryDelay = max(maximumAutomaticRetryDelay, 0)
        self.minimumRateLimitRetryDelay = max(minimumRateLimitRetryDelay, 0)
        self.apiKeyProvider = apiKeyProvider
        self.sleepHandler = sleepHandler
        self.nowProvider = nowProvider
        self.jitterProvider = jitterProvider
    }

    func estimateCalories(
        fromBase64Image base64Image: String,
        progress: AIRequestProgressHandler? = nil
    ) async throws -> NutritionEstimate {
        let cleanedImage = base64Image.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedImage.isEmpty else {
            throw NetworkManagerError.invalidEstimate
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Preparing image request",
                detail: "Building Gemini prompt with the compressed photo."
            )
        )

        let request = makeRequest(
            systemPrompt: GeminiConfiguration.nutritionistSystemPrompt,
            userParts: [
                GeminiPart(text: "Analyze this food image."),
                GeminiPart(inlineData: GeminiInlineData(mimeType: "image/jpeg", data: cleanedImage))
            ]
        )

        return try await estimate(
            key: .image(Self.sha256(cleanedImage)),
            request: request,
            models: [GeminiConfiguration.imageModel] + GeminiConfiguration.imageFallbackModels,
            expectedGrams: nil,
            progress: progress
        )
    }

    func estimateNutrition(
        foodName: String,
        grams: Int,
        progress: AIRequestProgressHandler? = nil
    ) async throws -> NutritionEstimate {
        let cleanedFoodName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedFoodName.isEmpty, grams > 0 else {
            throw NetworkManagerError.invalidEstimate
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Preparing text request",
                detail: "\(cleanedFoodName), \(grams) g."
            )
        )

        let request = makeRequest(
            systemPrompt: GeminiConfiguration.nutritionTextGuessSystemPrompt,
            userParts: [
                GeminiPart(
                    text: GeminiConfiguration.nutritionTextGuessUserPrompt(
                        foodName: cleanedFoodName,
                        grams: grams
                    )
                )
            ]
        )

        return try await estimate(
            key: .text(cleanedFoodName.lowercased(), grams),
            request: request,
            models: [GeminiConfiguration.textModel] + GeminiConfiguration.textFallbackModels,
            expectedGrams: grams,
            progress: progress
        )
    }

    private func estimate(
        key: RequestKey,
        request: GeminiRequest,
        models: [String],
        expectedGrams: Int?,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        removeExpiredCacheEntries()

        if let cachedEstimate = cache[key]?.estimate {
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .success,
                    title: "Using recent estimate",
                    detail: cachedEstimate.aiProgressSummary
                )
            )
            return cachedEstimate
        }

        if let activeRequest = inFlightRequests[key] {
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .active,
                    title: "Waiting for matching request",
                    detail: "The same request is already running, so this one will reuse it."
                )
            )
            let estimate = try await activeRequest.value
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .success,
                    title: "Matched request finished",
                    detail: estimate.aiProgressSummary
                )
            )
            return estimate
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Request schema ready",
                detail: "Gemini must return calories, grams, macros, and health score as JSON."
            )
        )

        let task = Task {
            try await requestNutritionEstimate(
                request,
                models: models,
                expectedGrams: expectedGrams,
                progress: progress
            )
        }
        inFlightRequests[key] = task

        do {
            let estimate = try await task.value
            cache[key] = CacheEntry(estimate: estimate, createdAt: nowProvider())
            inFlightRequests[key] = nil
            return estimate
        } catch {
            inFlightRequests[key] = nil
            throw error
        }
    }

    private func requestNutritionEstimate(
        _ requestBody: GeminiRequest,
        models: [String],
        expectedGrams: Int?,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        let availableModels = models.isEmpty ? [GeminiConfiguration.imageModel] : models
        var lastFailure: NetworkManagerError?

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Model plan",
                detail: availableModels.joined(separator: " -> ")
            )
        )

        for (index, model) in availableModels.enumerated() {
            if index > 0 {
                await report(
                    progress,
                    AIRequestProgressEvent(
                        kind: .warning,
                        title: "Trying fallback model",
                        detail: model
                    )
                )
            }

            do {
                return try await requestNutritionEstimateWithRetry(
                    requestBody,
                    model: model,
                    expectedGrams: expectedGrams,
                    retryLimit: index == 0 ? retryCount : 0,
                    rateLimitRetryLimit: index == 0 ? rateLimitRetryCount : 0,
                    progress: progress
                )
            } catch let error as NetworkManagerError {
                lastFailure = error

                guard index < availableModels.count - 1,
                      shouldTryNextModel(after: error, failedModelIndex: index) else {
                    throw error
                }

                await report(
                    progress,
                    AIRequestProgressEvent(
                        kind: .warning,
                        title: "Model failed",
                        detail: "\(model): \(error.progressDetail)"
                    )
                )
            }
        }

        throw lastFailure ?? NetworkManagerError.invalidResponse
    }

    private func requestNutritionEstimateWithRetry(
        _ requestBody: GeminiRequest,
        model: String,
        expectedGrams: Int?,
        retryLimit: Int,
        rateLimitRetryLimit: Int,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        var completedRetries = 0
        var completedRateLimitRetries = 0

        while true {
            try Task.checkCancellation()

            if let rateLimitError = activeRateLimitError() {
                guard completedRateLimitRetries < rateLimitRetryLimit,
                      let delay = automaticRetryDelay(
                        for: rateLimitError,
                        retryNumber: completedRateLimitRetries
                      ) else {
                    throw rateLimitError
                }

                completedRateLimitRetries += 1
                await report(
                    progress,
                    AIRequestProgressEvent(
                        kind: .warning,
                        title: "Local cooldown active",
                        detail: "Waiting \(Self.formattedDelay(delay)) before retrying \(model)."
                    )
                )
                try await sleepHandler(delay)
                continue
            }

            do {
                return try await performGatedRequest(
                    requestBody,
                    model: model,
                    expectedGrams: expectedGrams,
                    progress: progress
                )
            } catch let error as NetworkManagerError {
                recordRateLimitIfNeeded(error)

                let retryNumber: Int
                let allowedRetries: Int
                if case .rateLimited = error {
                    retryNumber = completedRateLimitRetries
                    allowedRetries = rateLimitRetryLimit
                } else {
                    retryNumber = completedRetries
                    allowedRetries = retryLimit
                }

                guard retryNumber < allowedRetries,
                      let delay = automaticRetryDelay(for: error, retryNumber: retryNumber) else {
                    throw error
                }

                if case .rateLimited = error {
                    completedRateLimitRetries += 1
                } else {
                    completedRetries += 1
                }

                await report(
                    progress,
                    AIRequestProgressEvent(
                        kind: .warning,
                        title: "Retrying request",
                        detail: "\(error.progressDetail) Waiting \(Self.formattedDelay(delay)) before attempt \(retryNumber + 2)."
                    )
                )
                try await sleepHandler(delay)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw NetworkManagerError.invalidResponse
            }
        }
    }

    private func shouldTryNextModel(
        after error: NetworkManagerError,
        failedModelIndex: Int
    ) -> Bool {
        if error.isModelFallbackEligible {
            return true
        }

        guard failedModelIndex > 0 else {
            return false
        }

        switch error {
        case .authorizationFailed, .rateLimited:
            return true
        default:
            return false
        }
    }

    private func performGatedRequest(
        _ requestBody: GeminiRequest,
        model: String,
        expectedGrams: Int?,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        let waited = await requestGate.acquire()
        if waited {
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .active,
                    title: "API slot ready",
                    detail: "Another local AI request finished; starting this one."
                )
            )
        }

        do {
            let estimate = try await performSingleRequest(
                requestBody,
                model: model,
                expectedGrams: expectedGrams,
                progress: progress
            )
            await requestGate.release()
            return estimate
        } catch {
            await requestGate.release()
            throw error
        }
    }

    private func performSingleRequest(
        _ requestBody: GeminiRequest,
        model: String,
        expectedGrams: Int?,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        let apiKey = apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NetworkManagerError.missingAPIKey
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Sending request to Gemini",
                detail: "Model \(model), 45s timeout."
            )
        )

        var request = URLRequest(
            url: GeminiConfiguration.generateContentURL(model: model, apiKey: apiKey)
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .failure,
                    title: "Network transport failed",
                    detail: error.localizedDescription
                )
            )
            throw NetworkManagerError.transport(error)
        } catch {
            throw NetworkManagerError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkManagerError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiMessage = apiErrorMessage(from: data)
            let apiError = makeAPIError(from: data, response: httpResponse)
            await report(
                progress,
                AIRequestProgressEvent(
                    kind: .warning,
                    title: "Gemini returned HTTP \(httpResponse.statusCode)",
                    detail: Self.combinedProgressDetail(
                        localDetail: apiError.progressDetail,
                        apiMessage: apiMessage
                    )
                )
            )
            throw apiError
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .success,
                title: "Gemini returned HTTP \(httpResponse.statusCode)",
                detail: "Decoding JSON response."
            )
        )

        guard let completion = try? decoder.decode(GeminiResponse.self, from: data) else {
            throw NetworkManagerError.decodingFailed
        }

        if let blockReason = completion.promptFeedback?.blockReason {
            throw NetworkManagerError.responseBlocked(blockReason)
        }

        guard let candidate = completion.candidates?.first else {
            throw NetworkManagerError.emptyResponse
        }

        let content = candidate.content?.parts?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !content.isEmpty else {
            if let finishReason = candidate.finishReason, finishReason != "STOP" {
                throw NetworkManagerError.responseBlocked(finishReason)
            }
            throw NetworkManagerError.emptyResponse
        }

        await report(
            progress,
            AIRequestProgressEvent(
                kind: .active,
                title: "Reading nutrition JSON",
                detail: "Gemini response text: \(content.count) characters."
            )
        )
        let estimate = try decodeNutritionEstimate(from: content)
        let validatedEstimate = try validatedEstimate(estimate, expectedGrams: expectedGrams)
        await report(
            progress,
            AIRequestProgressEvent(
                kind: .success,
                title: "Validated estimate",
                detail: validatedEstimate.aiProgressSummary
            )
        )
        return validatedEstimate
    }

    private func makeRequest(
        systemPrompt: String,
        userParts: [GeminiPart]
    ) -> GeminiRequest {
        GeminiRequest(
            systemInstruction: GeminiContent(
                role: nil,
                parts: [GeminiPart(text: systemPrompt)]
            ),
            contents: [
                GeminiContent(role: "user", parts: userParts)
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseSchema: .nutritionEstimate,
                temperature: 0.1,
                maxOutputTokens: 512
            )
        )
    }

    private func makeAPIError(
        from data: Data,
        response: HTTPURLResponse
    ) -> NetworkManagerError {
        let usefulMessage = apiErrorMessage(from: data)

        switch response.statusCode {
        case 400:
            return .badRequest(usefulMessage)
        case 401, 403:
            return .authorizationFailed(usefulMessage)
        case 404:
            return .modelUnavailable
        case 429:
            return .rateLimited(
                retryAfter: retryAfter(from: response, message: usefulMessage)
            )
        case 500...599:
            return .serviceUnavailable
        default:
            return .apiError(statusCode: response.statusCode, message: usefulMessage)
        }
    }

    private func apiErrorMessage(from data: Data) -> String? {
        let apiError = try? decoder.decode(GeminiErrorResponse.self, from: data)
        let message = apiError?.error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return message?.isEmpty == false ? message : nil
    }

    private func retryAfter(
        from response: HTTPURLResponse,
        message: String?
    ) -> TimeInterval? {
        if let header = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(header) {
            return max(seconds, 0)
        }

        guard let message else {
            return nil
        }

        let pattern = #"(?:retry(?:\s+in|Delay[^0-9]*)?|after)\s*([0-9]+(?:\.[0-9]+)?)\s*s"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = expression.firstMatch(in: message, range: range),
              let secondsRange = Range(match.range(at: 1), in: message),
              let seconds = TimeInterval(message[secondsRange]) else {
            return nil
        }

        return max(seconds, 0)
    }

    private func automaticRetryDelay(
        for error: NetworkManagerError,
        retryNumber: Int
    ) -> TimeInterval? {
        let baseDelay: TimeInterval

        switch error {
        case .rateLimited(let retryAfter):
            let fallbackDelay = min(
                minimumRateLimitRetryDelay * pow(2, Double(retryNumber)),
                maximumAutomaticRetryDelay
            )
            baseDelay = max(retryAfter ?? fallbackDelay, minimumRateLimitRetryDelay)
        case .serviceUnavailable:
            baseDelay = pow(2, Double(retryNumber))
        case .transport(let error) where Self.isRetryableTransportError(error):
            baseDelay = pow(2, Double(retryNumber))
        default:
            return nil
        }

        guard baseDelay <= maximumAutomaticRetryDelay else {
            return nil
        }

        return max(baseDelay, 0.5) + max(jitterProvider(), 0)
    }

    private func decodeNutritionEstimate(from content: String) throws -> NutritionEstimate {
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleanedContent.data(using: .utf8),
           let estimate = try? decoder.decode(NutritionEstimate.self, from: data) {
            return estimate
        }

        guard let openingBrace = cleanedContent.firstIndex(of: "{"),
              let closingBrace = cleanedContent.lastIndex(of: "}") else {
            throw NetworkManagerError.decodingFailed
        }

        let jsonSlice = cleanedContent[openingBrace...closingBrace]
        guard let jsonData = String(jsonSlice).data(using: .utf8),
              let estimate = try? decoder.decode(NutritionEstimate.self, from: jsonData) else {
            throw NetworkManagerError.decodingFailed
        }

        return estimate
    }

    private func validatedEstimate(
        _ estimate: NutritionEstimate,
        expectedGrams: Int?
    ) throws -> NutritionEstimate {
        let foodName = estimate.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        let grams = expectedGrams ?? estimate.estimatedGrams

        guard !foodName.isEmpty,
              estimate.estimatedCalories > 0,
              let grams, grams > 0,
              let protein = estimate.estimatedProteinGrams, protein >= 0,
              let carbs = estimate.estimatedCarbGrams, carbs >= 0,
              let fat = estimate.estimatedFatGrams, fat >= 0,
              let healthScore = estimate.healthScore, (1...10).contains(healthScore) else {
            throw NetworkManagerError.invalidEstimate
        }

        return NutritionEstimate(
            foodName: foodName,
            estimatedCalories: estimate.estimatedCalories,
            estimatedGrams: grams,
            estimatedProteinGrams: protein,
            estimatedCarbGrams: carbs,
            estimatedFatGrams: fat,
            healthScore: healthScore
        )
    }

    private func removeExpiredCacheEntries() {
        let now = nowProvider()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) <= cacheLifetime
        }
    }

    private func recordRateLimitIfNeeded(_ error: NetworkManagerError) {
        guard case .rateLimited(let retryAfter) = error else {
            return
        }

        let proposedCooldown = nowProvider().addingTimeInterval(
            max(retryAfter ?? minimumRateLimitRetryDelay, minimumRateLimitRetryDelay, 0.5)
        )

        if let rateLimitedUntil, rateLimitedUntil > proposedCooldown {
            return
        }

        rateLimitedUntil = proposedCooldown
    }

    private func activeRateLimitError() -> NetworkManagerError? {
        guard let rateLimitedUntil else {
            return nil
        }

        let remainingDelay = rateLimitedUntil.timeIntervalSince(nowProvider())
        guard remainingDelay > 0 else {
            self.rateLimitedUntil = nil
            return nil
        }

        return .rateLimited(retryAfter: remainingDelay)
    }

    private func report(
        _ progress: AIRequestProgressHandler?,
        _ event: AIRequestProgressEvent
    ) async {
        await progress?(event)
    }

    private static func isRetryableTransportError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func formattedDelay(_ delay: TimeInterval) -> String {
        let roundedDelay = Int(ceil(delay))
        if roundedDelay >= 60 {
            let minutes = roundedDelay / 60
            let seconds = roundedDelay % 60
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
        }
        return "\(roundedDelay)s"
    }

    private static func combinedProgressDetail(
        localDetail: String,
        apiMessage: String?
    ) -> String {
        guard let apiMessage, !apiMessage.isEmpty, apiMessage != localDetail else {
            return localDetail
        }

        return "\(localDetail) API message: \(apiMessage)"
    }

    static func defaultSleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else {
            return
        }

        let nanoseconds = UInt64(min(seconds, 60) * 1_000_000_000)
        try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
    }
}

enum NetworkManagerError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case responseBlocked(String)
    case decodingFailed
    case invalidEstimate
    case badRequest(String?)
    case authorizationFailed(String?)
    case modelUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case serviceUnavailable
    case transport(URLError)
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Enter a valid Gemini API key in Settings before using AI features."
        case .invalidResponse:
            return "The AI service returned an invalid response. Please try again."
        case .emptyResponse:
            return "The AI service returned an empty nutrition estimate."
        case .responseBlocked:
            return "The AI service could not analyze this request. Try a clearer food description or photo."
        case .decodingFailed:
            return "The nutrition estimate could not be read. Please try again."
        case .invalidEstimate:
            return "The AI estimate contained incomplete nutrition values. Please try again or enter them manually."
        case .badRequest(let message):
            return message ?? "The AI request was not accepted. Please check the entered values."
        case .authorizationFailed:
            return "The Gemini API key is invalid, restricted, or does not have access to this model."
        case .modelUnavailable:
            return "The configured Gemini model is currently unavailable."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "The Gemini usage limit was reached. Try again in about \(Int(ceil(retryAfter))) seconds."
            }
            return "The Gemini usage limit was reached. Wait a moment and try again."
        case .serviceUnavailable:
            return "The AI service is temporarily busy. Please try again shortly."
        case .transport(let error):
            if error.code == .notConnectedToInternet {
                return "There is no internet connection. Your entries are still available for manual editing."
            }
            return "The network request failed. \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "The AI request failed (\(statusCode)). \(message)"
            }
            return "The AI request failed with status code \(statusCode)."
        }
    }

    var canRetry: Bool {
        switch self {
        case .rateLimited, .serviceUnavailable, .invalidResponse, .emptyResponse,
             .decodingFailed, .invalidEstimate, .transport:
            return true
        default:
            return false
        }
    }

    var isModelFallbackEligible: Bool {
        switch self {
        case .serviceUnavailable, .modelUnavailable, .invalidResponse,
             .emptyResponse, .decodingFailed, .invalidEstimate:
            return true
        default:
            return false
        }
    }

    var alertTitle: String {
        switch self {
        case .missingAPIKey, .authorizationFailed, .modelUnavailable:
            return "AI Setup Required"
        case .rateLimited:
            return "AI Limit Reached"
        case .transport(let error) where error.code == .notConnectedToInternet:
            return "No Internet Connection"
        case .serviceUnavailable:
            return "AI Service Busy"
        default:
            return "AI Analysis"
        }
    }

    var progressDetail: String {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key is saved in Settings."
        case .invalidResponse:
            return "The response was not a valid Gemini HTTP response."
        case .emptyResponse:
            return "Gemini returned no nutrition text."
        case .responseBlocked(let reason):
            return "Gemini blocked the response: \(reason)."
        case .decodingFailed:
            return "The JSON could not be decoded into the nutrition fields."
        case .invalidEstimate:
            return "The estimate was missing required calories, grams, macros, or health score."
        case .badRequest(let message):
            return message ?? "Gemini rejected the request body."
        case .authorizationFailed(let message):
            return message ?? "The API key was rejected or lacks access to the selected model."
        case .modelUnavailable:
            return "The selected Gemini model is unavailable."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limit hit. Retry after about \(Int(ceil(retryAfter)))s."
            }
            return "Rate limit hit. Gemini did not provide a retry delay."
        case .serviceUnavailable:
            return "Gemini is temporarily busy or unavailable."
        case .transport(let error):
            return error.localizedDescription
        case .apiError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP \(statusCode) with no extra message."
        }
    }
}

private actor AIRequestGate {
    private var isOccupied = false
    private var waiters: [CheckedContinuation<Bool, Never>] = []

    func acquire() async -> Bool {
        guard isOccupied else {
            isOccupied = true
            return false
        }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isOccupied = false
            return
        }

        waiters.removeFirst().resume(returning: true)
    }
}

private enum RequestKey: Hashable {
    case image(String)
    case text(String, Int)
}

private struct CacheEntry {
    let estimate: NutritionEstimate
    let createdAt: Date
}

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
    let responseSchema: GeminiSchema
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiSchema: Encodable {
    let type: String
    let properties: [String: GeminiSchemaProperty]
    let required: [String]
    let propertyOrdering: [String]

    static let nutritionEstimate = GeminiSchema(
        type: "OBJECT",
        properties: [
            "food_name": GeminiSchemaProperty(type: "STRING"),
            "estimated_calories": GeminiSchemaProperty(type: "INTEGER", minimum: 1),
            "estimated_grams": GeminiSchemaProperty(type: "INTEGER", minimum: 1),
            "estimated_protein_grams": GeminiSchemaProperty(type: "INTEGER", minimum: 0),
            "estimated_carb_grams": GeminiSchemaProperty(type: "INTEGER", minimum: 0),
            "estimated_fat_grams": GeminiSchemaProperty(type: "INTEGER", minimum: 0),
            "health_score": GeminiSchemaProperty(type: "INTEGER", minimum: 1, maximum: 10)
        ],
        required: [
            "food_name",
            "estimated_calories",
            "estimated_grams",
            "estimated_protein_grams",
            "estimated_carb_grams",
            "estimated_fat_grams",
            "health_score"
        ],
        propertyOrdering: [
            "food_name",
            "estimated_calories",
            "estimated_grams",
            "estimated_protein_grams",
            "estimated_carb_grams",
            "estimated_fat_grams",
            "health_score"
        ]
    )
}

private struct GeminiSchemaProperty: Encodable {
    let type: String
    let minimum: Int?
    let maximum: Int?

    init(type: String, minimum: Int? = nil, maximum: Int? = nil) {
        self.type = type
        self.minimum = minimum
        self.maximum = maximum
    }
}

private struct GeminiContent: Encodable {
    let role: String?
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String?
    let inlineData: GeminiInlineData?

    init(text: String? = nil, inlineData: GeminiInlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
    let finishReason: String?
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

private struct GeminiResponsePart: Decodable {
    let text: String?
}

private struct GeminiPromptFeedback: Decodable {
    let blockReason: String?
}

private struct GeminiErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
