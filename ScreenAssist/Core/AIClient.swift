import Foundation

/// Sends OCR-extracted screen text to the selected AI provider.
/// Supports OpenAI (ChatGPT), Anthropic Claude, and Google Gemini.
/// Responses are capped at 150 tokens to keep them concise and cheap.
struct AIClient {

    private let systemPrompt = """
    You are a highly concise screen-reading assistant. \
    Answer in the fewest words possible. \
    Maximum 30 words unless more detail is explicitly requested. \
    Do not explain your reasoning unless asked.
    """

    // MARK: - Public

    func ask(
        question: String,
        context:  String,
        apiKey:   String,
        provider: AIProvider,
        model:    String
    ) async throws -> String {
        switch provider {
        case .openai:  return try await openai(q: question, ctx: context, key: apiKey, model: model)
        case .claude:  return try await claude(q: question, ctx: context, key: apiKey, model: model)
        case .gemini:  return try await gemini(q: question, ctx: context, key: apiKey, model: model)
        }
    }

    // MARK: - OpenAI

    private func openai(q: String, ctx: String, key: String, model: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 150,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userMsg(q: q, ctx: ctx)]
            ]
        ]
        var req = try buildRequest(url: url, body: body)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, res) = try await URLSession.shared.data(for: req)
        try checkHTTP(res, data: data, label: "OpenAI")

        struct R: Decodable {
            struct C: Decodable { struct M: Decodable { let content: String }; let message: M }
            let choices: [C]
        }
        return try JSONDecoder().decode(R.self, from: data).choices.first?.message.content.trimmed() ?? ""
    }

    // MARK: - Anthropic Claude

    private func claude(q: String, ctx: String, key: String, model: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 150,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMsg(q: q, ctx: ctx)]
            ]
        ]
        var req = try buildRequest(url: url, body: body)
        req.setValue(key,        forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, res) = try await URLSession.shared.data(for: req)
        try checkHTTP(res, data: data, label: "Claude")

        struct R: Decodable { struct B: Decodable { let text: String }; let content: [B] }
        return try JSONDecoder().decode(R.self, from: data).content.first?.text.trimmed() ?? ""
    }

    // MARK: - Google Gemini

    private func gemini(q: String, ctx: String, key: String, model: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else { throw AIErr.badURL }

        let fullPrompt = "\(systemPrompt)\n\n\(userMsg(q: q, ctx: ctx))"
        let body: [String: Any] = [
            "contents": [["parts": [["text": fullPrompt]]]],
            "generationConfig": ["maxOutputTokens": 150, "temperature": 0.3]
        ]
        let req = try buildRequest(url: url, body: body)

        let (data, res) = try await URLSession.shared.data(for: req)
        try checkHTTP(res, data: data, label: "Gemini")

        struct R: Decodable {
            struct C: Decodable {
                struct Ct: Decodable { struct P: Decodable { let text: String }; let parts: [P]? }
                let content: Ct?
            }
            let candidates: [C]?
        }
        return try JSONDecoder().decode(R.self, from: data)
            .candidates?.first?.content?.parts?.first?.text.trimmed() ?? ""
    }

    // MARK: - Shared helpers

    private func userMsg(q: String, ctx: String) -> String {
        "Screen content:\n\(ctx)\n\nQuestion: \(q)"
    }

    private func buildRequest(url: URL, body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func checkHTTP(_ response: URLResponse, data: Data, label: String) throws {
        guard let http = response as? HTTPURLResponse else { throw AIErr.noResponse }
        guard http.statusCode == 200 else {
            // Try to surface the provider's error message
            var msg = "HTTP \(http.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err  = json["error"] as? [String: Any],
               let txt  = err["message"] as? String {
                msg = txt
            }
            throw AIErr.api("[\(label)] \(msg)")
        }
    }
}

// MARK: - Error

enum AIErr: LocalizedError {
    case noResponse
    case badURL
    case api(String)

    var errorDescription: String? {
        switch self {
        case .noResponse:   return "No response from server"
        case .badURL:       return "Invalid API URL"
        case .api(let s):   return s
        }
    }
}

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
