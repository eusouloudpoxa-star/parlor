import Foundation

enum ChatPrompts {
    /// Plain-text turns. Every instruct-tuned GGUF still understands this legacy
    /// shape, and it keeps Parlor independent of any single model's chat template.
    static func build(persona: Persona, history: [Message], userText: String) -> String {
        var output = persona.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = persona.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            output += "\n\nLong-term notes about the person you are talking to: \(notes)"
        }
        output += "\n\n"
        for message in history where !isEffectivelyEmpty(message.text) {
            let who = message.role == .user ? "User" : persona.name
            output += "\(who): \(trimmed(message.text))\n"
        }
        output += "User: \(trimmed(userText))\n\(persona.name):"
        return output
    }

    /// True when the model starts a new turn unprompted.
    static func shouldStop(_ accumulated: String) -> Bool {
        accumulated.hasSuffix("User:")
    }

    static func cleanup(_ accumulated: String) -> String {
        var text = accumulated
        if let range = text.range(of: "\nUser:") {
            text = String(text[text.startIndex ..< range.lowerBound])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isEffectivelyEmpty(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
