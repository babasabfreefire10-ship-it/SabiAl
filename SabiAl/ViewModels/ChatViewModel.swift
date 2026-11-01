//
//  ChatViewModel.swift
//  SabiAl
//

import Foundation
import Combine

/// Holds the conversation, persists it across launches and streams the
/// bot's replies from the selected AI engine.
@MainActor
final class ChatViewModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published var isTyping = false
    @Published var errorMessage: String?

    private let storageKey = "sabial.chat.history"

    init() {
        load()
        if messages.isEmpty {
            appendGreeting()
        }
    }

    // MARK: - Sending

    /// Sends the user's message and streams the assistant's reply in,
    /// updating the last message as chunks arrive.
    func send(_ rawText: String) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }

        messages.append(ChatMessage(role: .user, text: text))
        isTyping = true
        defer { isTyping = false }

        let config = BotSettings.Config.load()
        let engine = AIService.configuredEngine()

        let placeholder = ChatMessage(role: .assistant, text: "")
        messages.append(placeholder)
        let placeholderIndex = messages.count - 1

        do {
            var lastText = ""
            for try await chunk in AIService.shared.stream(
                Array(messages.dropLast()),
                config: config,
                engine: engine
            ) {
                lastText = chunk
                messages[placeholderIndex].text = chunk
            }
            if lastText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[placeholderIndex].text = "Nuk mora përgjigje. Provoni përsëri."
            }
        } catch {
            // Keep any partial reply, otherwise drop the empty bubble.
            if messages[placeholderIndex].text.isEmpty {
                messages.remove(at: placeholderIndex)
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Admin actions

    /// Clears the conversation and restarts it with the current greeting.
    func restartWithCurrentGreeting() {
        messages.removeAll()
        appendGreeting()
    }

    /// Clears the conversation completely, without a greeting.
    func clearHistory() {
        messages.removeAll()
    }

    // MARK: - Persistence

    private func appendGreeting() {
        let config = BotSettings.Config.load()
        messages.append(ChatMessage(role: .assistant, text: config.greeting))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        messages = (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}