import Foundation

struct Persona: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var tagline: String
    var systemPrompt: String
    var notes: String
    var colorHex: String

    static func blank() -> Persona {
        Persona(
            id: UUID(),
            name: "New persona",
            tagline: "",
            systemPrompt: "You are a thoughtful, specific conversational partner with a clear point of view. Never break character. Keep answers under 130 words.",
            notes: "",
            colorHex: "#5B8CFF"
        )
    }
}
