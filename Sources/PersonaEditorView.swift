import SwiftUI

struct PersonaEditorView: View {
    let personaId: UUID

    @EnvironmentObject var personas: PersonaStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tagline = ""
    @State private var systemPrompt = ""
    @State private var notes = ""
    @State private var color = Color.blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    HStack {
                        ColorPicker("Color", selection: $color, supportsOpacity: false)
                        Spacer()
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                    }
                    TextField("Name", text: $name)
                    TextField("Tagline", text: $tagline)
                }
                Section("Character") {
                    TextField("System prompt", text: $systemPrompt, axis: .vertical)
                        .lineLimit(4 ... 12)
                }
                Section("Memory") {
                    TextField("Notes this persona remembers about you", text: $notes, axis: .vertical)
                        .lineLimit(2 ... 8)
                }
            }
            .navigationTitle("Edit persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let persona = personas.persona(id: personaId) else { return }
                name = persona.name
                tagline = persona.tagline
                systemPrompt = persona.systemPrompt
                notes = persona.notes
                color = Color(hex: persona.colorHex)
            }
        }
    }

    private func save() {
        guard var persona = personas.persona(id: personaId) else { return }
        persona.name = name
        persona.tagline = tagline
        persona.systemPrompt = systemPrompt
        persona.notes = notes
        persona.colorHex = color.hexString()
        personas.update(persona)
        dismiss()
    }
}
