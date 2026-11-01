//
//  ChatMessage.swift
//  SabiAl
//

import Foundation

/// A single message in the conversation with the bot.
struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()

    init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}
