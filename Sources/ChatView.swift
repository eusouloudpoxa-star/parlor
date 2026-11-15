import SwiftUI

private final class ScrollProxyBox: ObservableObject {
    var proxy: ScrollViewProxy?
}

struct ChatView: View {
    let chatId: UUID

    @EnvironmentObject var engine: LLMEngine
    @EnvironmentObject var chats: ChatStore
    @EnvironmentObject var personas: PersonaStore
    @StateObject private var proxyBox = ScrollProxyBox()
    @State private var draft = ""
    @State private var sharing: String?

    private var chat: Chat? { chats.chat(id: chatId) }
    private var persona: Persona? {
        chat.flatMap { personas.persona(id: $0.personaId) }
    }

    var body: some View {
        Group {
            if let chat, let persona {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(chat.messages) { message in
                                    bubble(message, persona: persona)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onAppear { proxyBox.proxy = proxy }
                    }

                    if engine.state == .noModel {
                        Label("No model installed — download it in Settings.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    composer
                }
                .navigationTitle(persona.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Export transcript") { export() }
                            Button("Clear chat") { chats.clear(chatId: chatId) }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { sharing != nil },
                    set: { if !$0 { sharing = nil } }
                )) {
                    if let sharing {
                        ShareSheet(text: sharing)
                            .presentationDetents([.medium])
                    }
                }
            } else {
                Text("Chat not found.")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: Message, persona: Persona) -> some View {
        let empty = message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(empty ? "…" : message.text)
                .padding(10)
                .background(message.role == .user
                    ? Color(.systemGray5)
                    : Color(hex: persona.colorHex).opacity(0.18))
                .foregroundColor(empty ? .secondary : .primary)
                .cornerRadius(14)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            if engine.state == .generating {
                Button(action: { engine.requestStop() }) {
                    Image(systemName: "stop.circle.fill").font(.title2)
                }
            }
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1 ... 5)
                .textFieldStyle(.roundedBorder)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.state != .ready)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let persona, engine.state == .ready else { return }
        draft = ""

        let prompt = ChatPrompts.build(persona: persona, history: chat?.messages ?? [], userText: text)
        chats.append(text, role: .user, to: chatId)
        let assistantId = chats.append("", role: .assistant, to: chatId)

        var accumulated = ""
        engine.generate(prompt: prompt) { piece in
            accumulated += piece
            if ChatPrompts.shouldStop(accumulated) {
                self.chats.update(messageId: assistantId, in: self.chatId,
                                  text: ChatPrompts.cleanup(accumulated))
                self.scrollToBottom()
                return false
            }
            self.chats.update(messageId: assistantId, in: self.chatId, text: accumulated)
            self.scrollToBottom()
            return true
        }
    }

    private func scrollToBottom() {
        guard let lastId = chats.chat(id: chatId)?.messages.last?.id else { return }
        withAnimation { proxyBox.proxy?.scrollTo(lastId, anchor: .bottom) }
    }

    private func export() {
        guard let chat, let persona else { return }
        sharing = chats.transcript(for: chat, personaName: persona.name)
    }
}
