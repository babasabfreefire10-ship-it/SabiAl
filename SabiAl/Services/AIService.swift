//
//  AIService.swift
//  SabiAl
//

import Foundation
import FoundationModels

enum AIError: LocalizedError {
    case invalidURL
    case server(status: Int, body: String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Adresa e API-së nuk është e vlefshme. Kontrollojeni në panelin e Admin-it."
        case .server(let status, let body):
            return "Serveri kthehi gabim (kodi \(status)): \(body)"
        case .badResponse:
            return "Përgjigja e serverit nuk u kuptua. Provoni përsëri."
        }
    }
}

/// The brain of the bot. The default engine is Apple Intelligence — the
/// on-device language model that runs for free, with no API key. An
/// OpenAI-compatible endpoint can be selected in the admin panel instead.
final class AIService {

    enum Engine: String {
        case appleIntelligence = "apple"
        case openAI = "openai"
    }

    static let shared = AIService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Engine selection

    /// The engine the admin chose in the panel. Apple Intelligence is the default.
    static func configuredEngine() -> Engine {
        Engine(rawValue: UserDefaults.standard.string(forKey: BotSettings.Keys.aiEngine) ?? "") ?? .appleIntelligence
    }

    /// A human-readable reason why Apple Intelligence cannot be used, or
    /// nil when the on-device model is ready.
    static var appleAvailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence nuk është aktivizuar në këtë pajisje."
        case .unavailable(.deviceNotEligible):
            return "Kjo pajisje nuk mbështet Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "Modeli i Apple Intelligence po shkarkohet dhe nuk është gati ende."
        case .unavailable:
            return "Apple Intelligence nuk është i disponueshëm."
        }
    }

    // MARK: - Streaming

    /// Streams the assistant's reply as cumulative text snapshots: each
    /// yielded value replaces the previous text, word by word.
    func stream(_ history: [ChatMessage], config: BotSettings.Config, engine: Engine) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let apiKey = ApiKeyManager.shared.get(key: "OPENAI_API_KEY")

                    if engine == .openAI, let apiKey, !apiKey.isEmpty {
                        let reply = try await self.sendViaOpenAI(history, config: config, apiKey: apiKey)
                        continuation.yield(reply)
                    } else if Self.appleAvailabilityReason == nil {
                        let appleSession = try LanguageModelSession(
                            instructions: "\(config.systemPrompt)"
                        )
                        let responseStream = appleSession.streamResponse(
                            to: Self.prompt(for: history, config: config)
                        )
                        var fullText = ""
                        for try await chunk in responseStream {
                            fullText = chunk.content
                            continuation.yield(fullText)
                        }
                        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continuation.yield(Self.demoReply(to: history.last?.text ?? ""))
                        }
                    } else {
                        // Neither engine is ready: keep the app usable in demo mode.
                        continuation.yield(Self.demoReply(to: history.last?.text ?? ""))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Apple Intelligence

    private static func prompt(for history: [ChatMessage], config: BotSettings.Config) -> String {
        var lines: [String] = []
        for message in history {
            let speaker = message.role == .user ? "Përdoruesi" : config.botName
            lines.append("\(speaker): \(message.text)")
        }
        return """
        Kjo është biseda deri tani:

        \(lines.joined(separator: "\n\n"))

        Përgjigju si \(config.botName) të mesazhit të fundit të përdoruesit.
        """
    }

    // MARK: - OpenAI-compatible endpoint

    private func sendViaOpenAI(_ history: [ChatMessage], config: BotSettings.Config, apiKey: String) async throws -> String {
        guard let url = URL(string: config.endpoint) else {
            throw AIError.invalidURL
        }

        var payloadMessages: [[String: Any]] = [
            ["role": "system", "content": config.systemPrompt]
        ]
        for message in history {
            payloadMessages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text
            ])
        }

        let payload: [String: Any] = [
            "model": config.model,
            "temperature": config.temperature,
            "messages": payloadMessages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.server(status: http.statusCode, body: body)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIError.badResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Demo mode

    /// Canned Albanian replies used while no engine is ready,
    /// so the app is fully usable the moment it launches.
    static func demoReply(to text: String) -> String {
        let t = text.lowercased()
        if t.contains("përshëndetje") || t.contains("pershendetje") || t.contains("tungjatjeta") || t.contains("hello") {
            return "Përshëndetje! Gëzohem që po bisedojmë. Çfarë ju duhet?"
        }
        if t.contains("si je") || t.contains("si po kalon") {
            return "Po shkëlqej, faleminderit! Ju si ndiheni sot?"
        }
        if t.contains("emri") || t.contains("kush je") {
            return "Unë jam Sabi, asistenti juaj virtual brenda aplikacionit SabiAl."
        }
        if t.contains("faleminderit") {
            return "As nuk ka përse! Këtu jam kurdo që ju duhet."
        }
        return """
            Ju dëgjova: „\(text)". \
            Motori i AI-së nuk është gati ende — kontrolloni panelin e Admin-it, \
            seksionin „Lidhja me AI-në".
            """
    }
}
