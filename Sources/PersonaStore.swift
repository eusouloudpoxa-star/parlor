import Foundation

final class PersonaStore: ObservableObject {
    @Published private(set) var personas: [Persona] = []

    private let file: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        file = docs.appendingPathComponent("personas.json")
        load()
    }

    func persona(id: UUID) -> Persona? {
        personas.first { $0.id == id }
    }

    func add(_ persona: Persona) {
        personas.append(persona)
        save()
    }

    func update(_ persona: Persona) {
        guard let index = personas.firstIndex(where: { $0.id == persona.id }) else { return }
        personas[index] = persona
        save()
    }

    func delete(at offsets: IndexSet) {
        personas.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([Persona].self, from: data) {
            personas = decoded
            return
        }
        // First launch: seed from the bundled set, then keep it user-editable in Documents.
        guard let bundled = Bundle.main.url(forResource: "personas", withExtension: "json"),
              let data = try? Data(contentsOf: bundled),
              let decoded = try? JSONDecoder().decode([Persona].self, from: data) else { return }
        personas = decoded
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(personas) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
