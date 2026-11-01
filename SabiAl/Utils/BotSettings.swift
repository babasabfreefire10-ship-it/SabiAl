//
//  BotSettings.swift
//  SabiAl
//

import Foundation

/// Keys and default values for every setting the admin panel controls.
/// All values live in UserDefaults so they survive launches.
enum BotSettings {

    enum Keys {
        static let botName = "sabial.bot.name"
        static let greeting = "sabial.bot.greeting"
        static let systemPrompt = "sabial.bot.systemPrompt"
        static let endpoint = "sabial.bot.endpoint"
        static let model = "sabial.bot.model"
        static let temperature = "sabial.bot.temperature"
        static let adminPIN = "sabial.admin.pin"
        static let aiEngine = "sabial.ai.engine"
    }

    enum Defaults {
        static let botName = "Sabi"
        static let greeting = "Përshëndetje! Unë jam Sabi, asistenti juaj virtual. Si mund t'ju ndihmoj sot?"
        static let systemPrompt = """
            Ti je Sabi, një asistent bisedues i miqshëm që flet vetëm në gjuhën shqipe. \
            Përgjigju shkurt e qartë, me ton miqësor dhe profesional. \
            Nëse nuk di diçka, thuaj sinqerisht që nuk e di dhe kërko sqarim.
            """
        static let endpoint = "https://api.openai.com/v1/chat/completions"
        static let model = "gpt-4o-mini"
        static let temperature = 0.7
        static let adminPIN = "1234"
        /// "apple" = Apple Intelligence (free, on-device), "openai" = remote API.
        static let aiEngine = "apple"
    }

    /// A plain snapshot of the bot configuration, read directly from
    /// UserDefaults. Used by the networking layer, which cannot hold
    /// SwiftUI property wrappers.
    struct Config {
        var botName: String
        var greeting: String
        var systemPrompt: String
        var endpoint: String
        var model: String
        var temperature: Double

        static func load() -> Config {
            let d = UserDefaults.standard
            return Config(
                botName: d.string(forKey: Keys.botName) ?? Defaults.botName,
                greeting: d.string(forKey: Keys.greeting) ?? Defaults.greeting,
                systemPrompt: d.string(forKey: Keys.systemPrompt) ?? Defaults.systemPrompt,
                endpoint: d.string(forKey: Keys.endpoint) ?? Defaults.endpoint,
                model: d.string(forKey: Keys.model) ?? Defaults.model,
                temperature: d.object(forKey: Keys.temperature) as? Double ?? Defaults.temperature
            )
        }
    }
}
