import Foundation

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func estimateCalories(fromBase64Image base64Image: String) async throws -> NutritionEstimate {
        let apiKey = OpenAIConfiguration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, apiKey != "YOUR_API_KEY" else {
            throw NetworkManagerError.missingAPIKey
        }

        var request = URLRequest(url: OpenAIConfiguration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let imageDataURL = "data:image/jpeg;base64,\(base64Image)"
        let requestBody = OpenAIChatCompletionRequest(
            model: OpenAIConfiguration.visionModel,
            messages: [
                OpenAIChatMessage(
                    role: "system",
                    content: .text(OpenAIConfiguration.nutritionistSystemPrompt)
                ),
                OpenAIChatMessage(
                    role: "user",
                    content: .parts([
                        .text("Analyze this food image."),
                        .image(dataURL: imageDataURL)
                    ])
                )
            ],
            maxCompletionTokens: 120,
            responseFormat: OpenAIResponseFormat(type: "json_object")
        )
        request.httpBody = try encoder.encode(requestBody)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw NetworkManagerError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkManagerError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw NetworkManagerError.apiError(apiError.error.message)
            }

            throw NetworkManagerError.apiError("OpenAI request failed with status code \(httpResponse.statusCode).")
        }

        let completion = try decoder.decode(OpenAIChatCompletionResponse.self, from: data)
        let message = completion.choices.first?.message

        if let refusal = message?.refusal,
           !refusal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NetworkManagerError.apiError(refusal)
        }

        guard let content = message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NetworkManagerError.emptyResponse
        }

        let estimate = try decodeNutritionEstimate(from: content)
        guard !estimate.foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              estimate.estimatedCalories > 0 else {
            throw NetworkManagerError.invalidEstimate
        }

        return estimate
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
        guard let jsonData = String(jsonSlice).data(using: .utf8) else {
            throw NetworkManagerError.decodingFailed
        }

        do {
            return try decoder.decode(NutritionEstimate.self, from: jsonData)
        } catch {
            throw NetworkManagerError.decodingFailed
        }
    }
}

enum NetworkManagerError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case decodingFailed
    case invalidEstimate
    case transport(URLError)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Replace YOUR_API_KEY in OpenAIConfiguration before using AI analysis."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .emptyResponse:
            return "The nutrition estimate was empty."
        case .decodingFailed:
            return "The nutrition estimate could not be parsed."
        case .invalidEstimate:
            return "The nutrition estimate did not include a valid food name and calories."
        case .transport(let error):
            return "Network request failed. \(error.localizedDescription)"
        case .apiError(let message):
            return message
        }
    }
}

private struct OpenAIChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let maxCompletionTokens: Int
    let responseFormat: OpenAIResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case responseFormat = "response_format"
    }
}

private struct OpenAIChatMessage: Encodable {
    let role: String
    let content: Content

    enum Content: Encodable {
        case text(String)
        case parts([OpenAIContentPart])

        func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let text):
                var container = encoder.singleValueContainer()
                try container.encode(text)
            case .parts(let parts):
                var container = encoder.singleValueContainer()
                try container.encode(parts)
            }
        }
    }
}

private struct OpenAIContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: OpenAIImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
    }

    static func text(_ text: String) -> OpenAIContentPart {
        OpenAIContentPart(type: "text", text: text, imageURL: nil)
    }

    static func image(dataURL: String) -> OpenAIContentPart {
        OpenAIContentPart(
            type: "image_url",
            text: nil,
            imageURL: OpenAIImageURL(url: dataURL)
        )
    }
}

private struct OpenAIImageURL: Encodable {
    let url: String
}

private struct OpenAIResponseFormat: Encodable {
    let type: String
}

private struct OpenAIChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
        let refusal: String?
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
