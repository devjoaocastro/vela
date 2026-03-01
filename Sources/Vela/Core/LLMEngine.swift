import Foundation
import Security

// MARK: - Message

struct LLMMessage {
    let role: String  // "user" | "assistant" | "system"
    let content: String
}

// MARK: - Provider Enum

enum LLMProviderType: String, CaseIterable, Codable {
    case ollama    = "Ollama (Local, Grátis)"
    case claude    = "Claude (Anthropic)"
    case openAI    = "OpenAI"
    case gemini    = "Google Gemini"

    var icon: String {
        switch self {
        case .ollama:  return "cpu"
        case .claude:  return "sparkles"
        case .openAI:  return "bolt.circle"
        case .gemini:  return "star.circle"
        }
    }

    var requiresKey: Bool { self != .ollama }

    var defaultModel: String {
        switch self {
        case .ollama:  return "llama3.2"
        case .claude:  return "claude-haiku-4-5-20251001"
        case .openAI:  return "gpt-4o-mini"
        case .gemini:  return "gemini-2.0-flash"
        }
    }

    var availableModels: [String] {
        switch self {
        case .ollama:
            return ["llama3.2", "llama3.1", "mistral", "mistral-nemo",
                    "codellama", "phi4", "deepseek-r1", "gemma3"]
        case .claude:
            return ["claude-haiku-4-5-20251001", "claude-sonnet-4-6",
                    "claude-opus-4-6"]
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
        }
    }
}

// MARK: - Settings

struct LLMSettings: Codable {
    var activeProvider: LLMProviderType = .ollama
    var ollamaURL: String = "http://localhost:11434"
    var ollamaModel: String = "llama3.2"
    var claudeModel: String = "claude-haiku-4-5-20251001"
    var openAIModel: String = "gpt-4o-mini"
    var geminiModel: String = "gemini-2.0-flash"

    var activeModel: String {
        switch activeProvider {
        case .ollama:  return ollamaModel
        case .claude:  return claudeModel
        case .openAI:  return openAIModel
        case .gemini:  return geminiModel
        }
    }
}

// MARK: - Keychain

struct KeychainStore {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vela.app",
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vela.app",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vela.app"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - LLMEngine

@MainActor
class LLMEngine: ObservableObject {
    @Published var settings: LLMSettings = LLMSettings()
    @Published var isAvailable: Bool = false

    private let settingsKey = "vela.llm.settings"

    // API key property names in Keychain
    private let claudeKeyName  = "vela.claude.apikey"
    private let openAIKeyName  = "vela.openai.apikey"
    private let geminiKeyName  = "vela.gemini.apikey"

    init() {
        loadSettings()
        Task { await checkAvailability() }
    }

    // MARK: - Keys

    var claudeKey: String  { KeychainStore.load(key: claudeKeyName)  ?? "" }
    var openAIKey: String  { KeychainStore.load(key: openAIKeyName)  ?? "" }
    var geminiKey: String  { KeychainStore.load(key: geminiKeyName)  ?? "" }

    func setClaudeKey(_ key: String)  { KeychainStore.save(key: claudeKeyName,  value: key) }
    func setOpenAIKey(_ key: String)  { KeychainStore.save(key: openAIKeyName,  value: key) }
    func setGeminiKey(_ key: String)  { KeychainStore.save(key: geminiKeyName,  value: key) }

    // MARK: - Availability Check

    func checkAvailability() async {
        switch settings.activeProvider {
        case .ollama:
            isAvailable = await checkOllama()
        case .claude:
            isAvailable = !claudeKey.isEmpty
        case .openAI:
            isAvailable = !openAIKey.isEmpty
        case .gemini:
            isAvailable = !geminiKey.isEmpty
        }
    }

    private func checkOllama() async -> Bool {
        guard let url = URL(string: settings.ollamaURL + "/api/tags") else { return false }
        return (try? await URLSession.shared.data(from: url)) != nil
    }

    // MARK: - Completion

    func complete(system: String, userMessage: String) async throws -> String {
        let messages = [LLMMessage(role: "user", content: userMessage)]
        switch settings.activeProvider {
        case .ollama:  return try await ollamaComplete(system: system, messages: messages)
        case .claude:  return try await claudeComplete(system: system, messages: messages)
        case .openAI:  return try await openAIComplete(system: system, messages: messages)
        case .gemini:  return try await geminiComplete(system: system, messages: messages)
        }
    }

    // MARK: - Ollama

    private func ollamaComplete(system: String, messages: [LLMMessage]) async throws -> String {
        let url = URL(string: settings.ollamaURL + "/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": settings.ollamaModel,
            "stream": false,
            "messages": [
                ["role": "system", "content": system]
            ] + messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }

    // MARK: - Claude

    private func claudeComplete(system: String, messages: [LLMMessage]) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(claudeKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": settings.claudeModel,
            "max_tokens": 2048,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        return content?.first?["text"] as? String ?? ""
    }

    // MARK: - OpenAI

    private func openAIComplete(system: String, messages: [LLMMessage]) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.openAIModel,
            "messages": [
                ["role": "system", "content": system]
            ] + messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }

    // MARK: - Gemini

    private func geminiComplete(system: String, messages: [LLMMessage]) async throws -> String {
        let model = settings.geminiModel
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(geminiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var parts: [[String: Any]] = [["text": system + "\n\n"]]
        for msg in messages { parts.append(["text": msg.content]) }

        let body: [String: Any] = [
            "contents": [["parts": parts]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let geminiParts = content?["parts"] as? [[String: Any]]
        return geminiParts?.first?["text"] as? String ?? ""
    }

    // MARK: - Project Analysis Prompts

    func analyseProject(_ project: Project) async throws -> ProjectAnalysis {
        let system = """
        És um assistente de análise de projectos de software. Respondes sempre em português europeu (Portugal).
        Analisa projectos de forma técnica, honesta e directa. Não uses linguagem corporativa.
        Responde APENAS com JSON válido, sem markdown code blocks.
        """

        let context = buildProjectContext(project)

        let prompt = """
        Analisa este projecto de software e devolve JSON com exactamente este formato:
        {
          "summary": "Resumo técnico em 2-3 frases do que é este projecto",
          "assessment": "Avaliação honesta do estado actual (1-2 frases)",
          "strengths": ["ponto forte 1", "ponto forte 2"],
          "weaknesses": ["ponto fraco 1", "ponto fraco 2"],
          "nextSteps": ["próximo passo concreto 1", "próximo passo concreto 2", "próximo passo concreto 3"],
          "verdict": "CONTINUA | ARQUIVA | REFACTORA | LANÇA"
        }

        Dados do projecto:
        \(context)
        """

        let response = try await complete(system: system, userMessage: prompt)
        return try parseAnalysis(response)
    }

    func generateReadme(_ project: Project) async throws -> String {
        let system = "És um programador sénior. Escreves READMEs claros e técnicos em inglês, em formato Markdown."
        let context = buildProjectContext(project)
        let prompt = "Gera um README.md completo para este projecto:\n\n\(context)"
        return try await complete(system: system, userMessage: prompt)
    }

    func chatAboutProject(_ project: Project, message: String, history: [LLMMessage]) async throws -> String {
        let system = """
        És um assistente técnico especializado neste projecto: \(project.name).
        Stack: \(project.type.rawValue). Path: \(project.path).
        Respondes em português europeu, de forma directa e técnica.
        """
        var messages = history
        messages.append(LLMMessage(role: "user", content: message))
        switch settings.activeProvider {
        case .ollama: return try await ollamaComplete(system: system, messages: messages)
        case .claude: return try await claudeComplete(system: system, messages: messages)
        case .openAI: return try await openAIComplete(system: system, messages: messages)
        case .gemini: return try await geminiComplete(system: system, messages: messages)
        }
    }

    // MARK: - Helpers

    private func buildProjectContext(_ project: Project) -> String {
        var ctx = """
        Nome: \(project.name)
        Tipo: \(project.type.rawValue)
        Status: \(project.status.rawValue)
        Vitalidade: \(project.vitalityScore)/100
        Git: \(project.git.hasGit ? "Sim" : "Não")
        """
        if let msg = project.git.lastCommitMessage { ctx += "\nÚltimo commit: \(msg)" }
        if let days = project.git.daysSinceLastCommit { ctx += "\nDias desde último commit: \(days)" }
        ctx += "\nTotal commits: \(project.git.totalCommits)"
        ctx += "\nRemote: \(project.git.hasRemote ? project.git.remoteURL ?? "Sim" : "Não")"
        ctx += "\nProblemas detectados: \(project.issues.map { $0.message }.joined(separator: ", "))"
        if !project.description.isEmpty { ctx += "\nDescrição: \(project.description)" }
        if !project.markdownFiles.isEmpty {
            ctx += "\nFicheiros .md: \(project.markdownFiles.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))"
        }
        return ctx
    }

    private func parseAnalysis(_ json: String) throws -> ProjectAnalysis {
        let clean = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ProjectAnalysis.self, from: data)
        return decoded
    }

    // MARK: - Persistence

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(LLMSettings.self, from: data) else { return }
        settings = s
    }
}

// MARK: - Analysis Model

struct ProjectAnalysis: Codable, Identifiable {
    var id = UUID()
    let summary: String
    let assessment: String
    let strengths: [String]
    let weaknesses: [String]
    let nextSteps: [String]
    let verdict: String

    enum CodingKeys: String, CodingKey {
        case summary, assessment, strengths, weaknesses, nextSteps, verdict
    }

    var verdictColor: String {
        switch verdict {
        case "LANÇA":     return "#10B981"
        case "CONTINUA":  return "#3B82F6"
        case "REFACTORA": return "#F59E0B"
        case "ARQUIVA":   return "#EF4444"
        default:          return "#6B7280"
        }
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidResponse
    case noAPIKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Resposta inválida do modelo"
        case .noAPIKey:           return "API key não configurada"
        case .networkError(let m): return "Erro de rede: \(m)"
        }
    }
}
