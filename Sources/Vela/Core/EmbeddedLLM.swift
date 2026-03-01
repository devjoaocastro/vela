import Foundation

// MARK: - EmbeddedLLM
// Priority:
//   1. Apple Intelligence (FoundationModels, macOS 15.4+) — on-device, zero download, automatic
//   2. Ollama local                                        — free, offline
//   3. Unavailable                                         — user must configure API

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class EmbeddedLLM: ObservableObject {
    @Published var state: EmbeddedState = .checking
    @Published var backend: EmbeddedBackend = .unknown

    enum EmbeddedState: Equatable {
        case checking, ready, unavailable(String)
    }
    enum EmbeddedBackend: Equatable {
        case appleIntelligence, ollama(String), unknown
    }

    init() { Task { await detect() } }

    func detect() async {
        state = .checking
        if await checkAppleIntelligence() { backend = .appleIntelligence; state = .ready; return }
        if let m = await detectOllama() { backend = .ollama(m); state = .ready; return }
        backend = .unknown
        state = .unavailable("Configura um provider em Definições → LLM & AI")
    }

    private func checkAppleIntelligence() async -> Bool {
        #if canImport(FoundationModels)
        if #available(macOS 15.4, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    private func detectOllama() async -> String? {
        guard let url = URL(string: "http://localhost:11434/api/tags"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]],
              let name = (models.first)?["name"] as? String else { return nil }
        return name
    }

    func generate(system: String, userMessage: String) async throws -> String {
        switch backend {
        case .appleIntelligence: return try await withAppleIntelligence(system: system, prompt: userMessage)
        case .ollama(let m):     return try await withOllama(model: m, system: system, prompt: userMessage)
        case .unknown:           throw EmbeddedError.notAvailable
        }
    }

    private func withAppleIntelligence(system: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 15.4, *) {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw EmbeddedError.notAvailable
    }

    private func withOllama(model: String, system: String, prompt: String) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "stream": false,
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]]
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["message"] as? [String: Any])?["content"] as? String ?? ""
    }

    var isReady: Bool { if case .ready = state { return true }; return false }
    var statusLabel: String {
        switch backend {
        case .appleIntelligence: return "Apple Intelligence (on-device)"
        case .ollama(let m):     return "Ollama · \(m)"
        case .unknown:
            if case .unavailable(let m) = state { return m }
            return "A detectar…"
        }
    }
    var backendIcon: String {
        switch backend {
        case .appleIntelligence: return "applelogo"
        case .ollama:            return "cpu"
        case .unknown:           return "questionmark.circle"
        }
    }
}

enum EmbeddedError: LocalizedError {
    case notAvailable
    var errorDescription: String? { "Modelo local não disponível. Configura um provider nas Definições." }
}
