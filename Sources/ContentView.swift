import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: LLMEngine

    var body: some View {
        TabView {
            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            PersonaListView()
                .tabItem { Label("Personas", systemImage: "person.2") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear { engine.loadModel() }
    }
}
