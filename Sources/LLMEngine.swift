import Foundation
import llama

enum ParlorModel {
    static let defaultURL = "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
}

enum EngineState: Equatable {
    case noModel
    case ready
    case generating
}

final class LLMEngine: ObservableObject {
    static let modelFileName = "parlor-model.gguf"
    private static let contextSize: Int32 = 4096
    private static let maxGenerationTokens = 900

    @Published private(set) var state: EngineState = .noModel
    @Published private(set) var modelFileName: String = ""
    @Published private(set) var downloadProgress: Double? = nil
    @Published var temperature: Double = 0.7

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    // Stop flag: written on main (button), read on the generation queue.
    // A plain bool is fine here — worst case is one extra generated token.
    private var stopRequested = false
    private var progressObservation: NSKeyValueObservation?

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var modelPath: URL {
        documents.appendingPathComponent("models/\(Self.modelFileName)")
    }

    var hasModelOnDisk: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    var statusLine: String {
        switch state {
        case .noModel:
            return hasModelOnDisk ? "Model on disk, not loaded" : "No model installed"
        case .ready:
            return "Ready — \(modelFileName)"
        case .generating:
            return "Generating…"
        }
    }

    init() {
        llama_backend_init()
    }

    deinit {
        unloadModel()
        progressObservation?.invalidate()
        llama_backend_free()
    }

    func loadModel() {
        guard state == .noModel, hasModelOnDisk else { return }
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 0 // CPU-only: the llama.cpp SPM target builds without Metal.
        guard let loadedModel = llama_model_load_from_file(modelPath.path, modelParams) else {
            state = .noModel
            return
        }
        model = loadedModel
        vocab = llama_model_get_vocab(loadedModel)

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = Self.contextSize
        contextParams.n_batch = 512
        let threads = Int32(max(2, ProcessInfo.processInfo.processorCount / 2))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            unloadModel()
            return
        }
        context = loadedContext
        modelFileName = modelPath.lastPathComponent
        state = .ready
    }

    private func unloadModel() {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        context = nil
        model = nil
        vocab = nil
        modelFileName = ""
        state = .noModel
    }

    func requestStop() {
        stopRequested = true
    }

    func downloadModel(from urlString: String) {
        guard downloadProgress == nil, !urlString.isEmpty, let url = URL(string: urlString) else { return }
        downloadProgress = 0
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, _ in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.downloadProgress = nil } }
            guard let tempURL else { return }
            do {
                let directory = self.modelPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: self.modelPath.path) {
                    try FileManager.default.removeItem(at: self.modelPath)
                }
                try FileManager.default.moveItem(at: tempURL, to: self.modelPath)
                DispatchQueue.main.async { self.loadModel() }
            } catch {
                // File landed nowhere usable; UI stays on "not installed".
            }
        }
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async { self?.downloadProgress = progress.fractionCompleted }
        }
        task.resume()
    }

    /// Streams generated text through `onToken`. Returning false from the callback stops generation.
    func generate(prompt: String, onToken: @escaping (String) -> Bool) {
        guard state == .ready, let context, let vocab else { return }
        state = .generating
        stopRequested = false

        let sampler = makeSampler()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                if let sampler { llama_sampler_free(sampler) }
                DispatchQueue.main.async { self?.state = .ready }
            }
            guard let self, let sampler else { return }

            llama_kv_cache_clear(context)
            var promptTokens = self.tokenize(prompt, addSpecial: true)
            guard !promptTokens.isEmpty else { return }

            var batch = llama_batch_get_one(&promptTokens, Int32(promptTokens.count))
            var singleToken: [llama_token] = [0]
            var keepGoing = true
            var produced = 0

            while keepGoing && produced < Self.maxGenerationTokens && !self.stopRequested {
                if llama_decode(context, batch) != 0 { break }
                let token = llama_sampler_sample(sampler, context, -1)
                if llama_vocab_is_eog(vocab, token) { break }
                let piece = self.piece(for: token)
                produced += 1
                if !piece.isEmpty {
                    DispatchQueue.main.sync { keepGoing = onToken(piece) }
                }
                if !keepGoing { break }
                singleToken[0] = token
                batch = llama_batch_get_one(&singleToken, 1)
            }
        }
    }

    private func makeSampler() -> OpaquePointer? {
        let params = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(params) else { return nil }
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(Float32(temperature)))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0 ... UInt32.max)))
        return chain
    }

    private func tokenize(_ text: String, addSpecial: Bool) -> [llama_token] {
        guard let vocab else { return [] }
        let utf8Count = text.utf8.count
        var buffer = [llama_token](repeating: 0, count: max(16, utf8Count + 16))
        let count = llama_tokenize(vocab, text, Int32(utf8Count), &buffer, Int32(buffer.count), addSpecial, true)
        guard count > 0 else { return [] }
        return Array(buffer.prefix(Int(count)))
    }

    private func piece(for token: llama_token) -> String {
        guard let vocab else { return "" }
        var buffer = [CChar](repeating: 0, count: 128)
        let count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
        guard count > 0 else { return "" }
        let bytes = buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
