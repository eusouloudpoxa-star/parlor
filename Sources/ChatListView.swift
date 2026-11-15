import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var chats: ChatStore
    @EnvironmentObject var personas: PersonaStore
    @State private var path: [UUID] = []
    @State private var pickingPersona = false

    private var ordered: [Chat] { chats.sorted() }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(ordered) { chat in
                    NavigationLink(value: chat.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(personas.persona(id: chat.personaId)?.name ?? "Unknown persona")
                                .font(.headline)
                            HStack {
                                Text(chat.messages.last?.text ?? "Empty chat")
                                    .lineLimit(1)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(chat.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteChats)
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { pickingPersona = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { chatId in
                ChatView(chatId: chatId)
            }
            .sheet(isPresented: $pickingPersona) {
                PersonaPickerView { personaId in
                    let chat = chats.newChat(personaId: personaId)
                    pickingPersona = false
                    path = [chat.id]
                }
            }
            .overlay {
                if ordered.isEmpty {
                    Text("No chats yet — tap the pencil to start one.")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func deleteChats(at offsets: IndexSet) {
        let targets = offsets.map { ordered[$0] }
        for chat in targets { chats.delete(chat: chat) }
    }
}

struct PersonaPickerView: View {
    @EnvironmentObject var personas: PersonaStore
    @Environment(\.dismiss) private var dismiss
    let onPick: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List(personas.personas) { persona in
                Button { onPick(persona.id) } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: persona.colorHex))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(persona.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(persona.tagline)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
