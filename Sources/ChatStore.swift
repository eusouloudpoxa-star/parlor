import Foundation

struct Message: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID
    var role: Role
    var text: String
    var createdAt: Date
}

struct Chat: Identifiable, Codable, Equatable {
    var id: UUID
    var personaId: UUID
    var messages: [Message]
    var updatedAt: Date
}

final class ChatStore: ObservableObject {
    @Published private(set) var chats: [Chat] = []

    private let file: URL
    private let maxMessagesPerChat = 500

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        file = docs.appendingPathComponent("chats.json")
        load()
    }

    func sorted() -> [Chat] {
        chats.sorted { $0.updatedAt > $1.updatedAt }
    }

    func chat(id: UUID) -> Chat? {
        chats.first { $0.id == id }
    }

    @discardableResult
    func newChat(personaId: UUID) -> Chat {
        let chat = Chat(id: UUID(), personaId: personaId, messages: [], updatedAt: Date())
        chats.append(chat)
        save()
        return chat
    }

    @discardableResult
    func append(_ text: String, role: Message.Role, to chatId: UUID) -> UUID {
        guard var chat = self.chat(id: chatId) else { return UUID() }
        let message = Message(id: UUID(), role: role, text: text, createdAt: Date())
        chat.messages.append(message)
        if chat.messages.count > maxMessagesPerChat {
            chat.messages.removeFirst(chat.messages.count - maxMessagesPerChat)
        }
        chat.updatedAt = Date()
        replace(chat)
        return message.id
    }

    func update(messageId: UUID, in chatId: UUID, text: String) {
        guard var chat = self.chat(id: chatId),
              let index = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        chat.messages[index].text = text
        chat.updatedAt = Date()
        replace(chat)
    }

    func clear(chatId: UUID) {
        guard var chat = self.chat(id: chatId) else { return }
        chat.messages.removeAll()
        chat.updatedAt = Date()
        replace(chat)
    }

    func delete(chat: Chat) {
        chats.removeAll { $0.id == chat.id }
        save()
    }

    func transcript(for chat: Chat, personaName: String) -> String {
        let stamp = ISO8601DateFormatter().string(from: chat.updatedAt)
        var out = "# \(personaName) — \(stamp)\n\n"
        for message in chat.messages {
            let who = message.role == .user ? "You" : personaName
            out += "**\(who)**: \(message.text)\n\n"
        }
        return out
    }

    private func replace(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([Chat].self, from: data) else { return }
        chats = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
