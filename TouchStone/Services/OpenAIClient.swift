import Foundation

actor OpenAIClient {
    enum OpenAIError: Error, LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(Int, String?)
        case decodingError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Please add your OpenAI API key in Settings."
            case .invalidResponse:
                return "Invalid response from OpenAI."
            case .httpError(let code, let message):
                return "HTTP Error \(code): \(message ?? "Unknown error")"
            case .decodingError(let message):
                return "Failed to parse response: \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini"

    // MARK: - Chat Completion

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat?

        struct ResponseFormat: Codable {
            let type: String
        }
    }

    struct ChatResponse: Codable {
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message
        }
    }

    func chat(
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.7,
        jsonMode: Bool = false
    ) async throws -> String {
        guard let apiKey = APIKeyManager.shared.openAIKey else {
            throw OpenAIError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: userMessage)
        ]

        let chatRequest = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            response_format: jsonMode ? .init(type: "json_object") : nil
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenAIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw OpenAIError.httpError(httpResponse.statusCode, errorMessage)
        }

        do {
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = chatResponse.choices.first?.message.content else {
                throw OpenAIError.invalidResponse
            }
            return content
        } catch let error as DecodingError {
            throw OpenAIError.decodingError(String(describing: error))
        }
    }

    // MARK: - JSON Chat

    func chatJSON<T: Decodable>(
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.7,
        responseType: T.Type
    ) async throws -> T {
        let content = try await chat(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: temperature,
            jsonMode: true
        )

        guard let data = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenAIError.decodingError("Failed to decode response: \(error)")
        }
    }
}
