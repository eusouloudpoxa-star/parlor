import SwiftUI

private struct EditID: Identifiable { let id: UUID }

struct PersonaListView: View {
    @EnvironmentObject var personas: PersonaStore
    @State private var editingId: EditID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(personas.personas) { persona in
                    Button { editingId = EditID(id: persona.id) } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: persona.colorHex))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(persona.name).font(.headline).foregroundColor(.primary)
                                Text(persona.tagline)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete(perform: personas.delete)
            }
            .navigationTitle("Personas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let persona = Persona.blank()
                        personas.add(persona)
                        editingId = EditID(id: persona.id)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingId) { editID in
                PersonaEditorView(personaId: editID.id)
            }
        }
    }
}
