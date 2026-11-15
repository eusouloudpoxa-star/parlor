import SwiftUI

@main
struct ParlorApp: App {
    @StateObject private var engine = LLMEngine()
    @StateObject private var chats = ChatStore()
    @StateObject private var personas = PersonaStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(chats)
                .environmentObject(personas)
        }
    }
}
