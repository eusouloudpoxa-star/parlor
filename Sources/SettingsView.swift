import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: LLMEngine
    @AppStorage("modelURL") private var modelURL: String = ParlorModel.defaultURL

    private var modelURLIsValid: Bool {
        guard let url = URL(string: modelURL) else { return false }
        return ["http", "https"].contains(url.scheme ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    if engine.hasModelOnDisk {
                        Label("Model installed", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                    } else {
                        Text("Parlor needs a GGUF model (~1 GB). Download over Wi-Fi, or drop a file named \(LLMEngine.modelFileName) into the Parlor/models folder in the Files app.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        TextField("Model URL", text: $modelURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if let progress = engine.downloadProgress {
                            ProgressView(value: progress)
                        } else {
                            Button("Download model") {
                                engine.downloadModel(from: modelURL)
                            }
                            .disabled(!modelURLIsValid)
                        }
                    }
                    Text(engine.statusLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Generation") {
                    HStack {
                        Text("Temperature")
                        Slider(value: $engine.temperature, in: 0.1 ... 1.2)
                        Text(String(format: "%.2f", engine.temperature))
                            .monospacedDigit()
                    }
                }
                Section("About") {
                    Text("Parlor runs models on-device. No account, no ads, no server. Chats and personas stay inside this app container.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear { engine.loadModel() }
        }
    }
}
