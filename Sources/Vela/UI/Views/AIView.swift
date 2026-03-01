import SwiftUI

// MARK: - AI Analysis + Chat Tab

struct AIView: View {
    let project: Project
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM

    @State private var analysis: ProjectAnalysis? = nil
    @State private var isAnalysing: Bool = false
    @State private var analysisError: String? = nil
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput: String = ""
    @State private var isChatting: Bool = false
    @State private var selectedSection: AISection = .analyse

    enum AISection: String, CaseIterable {
        case analyse = "Análise"
        case chat    = "Chat"
        case readme  = "README"
    }

    var body: some View {
        VStack(spacing: 0) {
            // AI Section Picker
            HStack {
                Picker("", selection: $selectedSection) {
                    ForEach(AISection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                // Active provider badge
                HStack(spacing: 4) {
                    Image(systemName: activeProviderIcon)
                        .font(.system(size: 10))
                    Text(activeProviderLabel)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quinary)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                switch selectedSection {
                case .analyse: AnalyseSection(project: project, analysis: $analysis,
                                              isAnalysing: $isAnalysing, error: $analysisError)
                case .chat:    ChatSection(project: project, messages: $chatMessages,
                                          input: $chatInput, isLoading: $isChatting)
                case .readme:  ReadmeSection(project: project)
                }
            }
        }
    }

    private var activeProviderLabel: String {
        if embeddedLLM.isReady { return "SmolLM2 (local)" }
        return llmEngine.settings.activeProvider.rawValue
    }

    private var activeProviderIcon: String {
        if embeddedLLM.isReady { return "cpu" }
        return llmEngine.settings.activeProvider.icon
    }
}

// MARK: - Analyse Section

struct AnalyseSection: View {
    let project: Project
    @Binding var analysis: ProjectAnalysis?
    @Binding var isAnalysing: Bool
    @Binding var error: String?
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let analysis {
                AnalysisResultView(analysis: analysis)

                Button("Reanalisar") { Task { await analyse() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

            } else if isAnalysing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("A analisar o projecto…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("O modelo está a ler o contexto do projecto.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)

            } else {
                VStack(spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.6))

                    Text("Análise com AI")
                        .font(.title3.bold())

                    Text("O modelo analisa o estado técnico do projecto:\nestado, pontos fortes, fraquezas e próximos passos.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.callout)

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Button("Analisar Projecto") {
                        Task { await analyse() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isProviderReady)

                    if !isProviderReady {
                        Text("Configura um provider em Definições ou descarrega o SmolLM2.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
        .padding(20)
    }

    private var isProviderReady: Bool {
        embeddedLLM.isReady || llmEngine.isAvailable
    }

    private func analyse() async {
        isAnalysing = true
        error = nil
        do {
            if embeddedLLM.isReady {
                // Use embedded SmolLM2
                let system = "Analisa projectos de software. Responde APENAS em JSON válido sem markdown."
                let context = buildContext()
                let raw = try await embeddedLLM.generate(system: system, userMessage: context)
                analysis = try parseAnalysis(raw)
            } else {
                analysis = try await llmEngine.analyseProject(project)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isAnalysing = false
    }

    private func buildContext() -> String {
        """
        Analisa e devolve JSON:
        {"summary":"...","assessment":"...","strengths":["..."],"weaknesses":["..."],"nextSteps":["..."],"verdict":"CONTINUA|ARQUIVA|REFACTORA|LANÇA"}

        Projecto: \(project.name), \(project.type.rawValue), \(project.status.rawValue)
        Git: \(project.git.hasGit ? "sim" : "não"), commits: \(project.git.totalCommits)
        Último commit: \(project.git.lastCommitMessage ?? "—")
        Problemas: \(project.issues.map { $0.message }.joined(separator: ", "))
        """
    }

    private func parseAnalysis(_ raw: String) throws -> ProjectAnalysis {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extract JSON from potential extra text
        let jsonStr: String
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            jsonStr = String(cleaned[start...end])
        } else {
            jsonStr = cleaned
        }
        guard let data = jsonStr.data(using: .utf8) else { throw LLMError.invalidResponse }
        return try JSONDecoder().decode(ProjectAnalysis.self, from: data)
    }
}

// MARK: - Analysis Result

struct AnalysisResultView: View {
    let analysis: ProjectAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Verdict
            HStack {
                Text(analysis.verdict)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: analysis.verdictColor))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(hex: analysis.verdictColor).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
            }

            // Summary
            VStack(alignment: .leading, spacing: 4) {
                Label("Resumo", systemImage: "text.quote").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(analysis.summary).font(.callout)
            }

            // Assessment
            VStack(alignment: .leading, spacing: 4) {
                Label("Avaliação", systemImage: "eye").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(analysis.assessment).font(.callout).foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                // Strengths
                VStack(alignment: .leading, spacing: 6) {
                    Label("Pontos Fortes", systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    ForEach(analysis.strengths, id: \.self) { s in
                        HStack(alignment: .top, spacing: 4) {
                            Text("✓").foregroundStyle(.green).font(.caption)
                            Text(s).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Weaknesses
                VStack(alignment: .leading, spacing: 6) {
                    Label("Fraquezas", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(analysis.weaknesses, id: \.self) { w in
                        HStack(alignment: .top, spacing: 4) {
                            Text("✗").foregroundStyle(.orange).font(.caption)
                            Text(w).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Next Steps
            VStack(alignment: .leading, spacing: 6) {
                Label("Próximos Passos", systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                ForEach(Array(analysis.nextSteps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(step).font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chat Section

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String  // "user" | "assistant"
    let content: String
    let date = Date()
}

struct ChatSection: View {
    let project: Project
    @Binding var messages: [ChatMessage]
    @Binding var input: String
    @Binding var isLoading: Bool
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Chat sobre \(project.name)")
                        .font(.headline)
                    Text("Pergunta qualquer coisa sobre o projecto.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    // Suggestions
                    VStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { input = s; Task { await send() } }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal, 20)
            } else {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        if isLoading {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("A pensar…").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .onChange(of: messages.count) { _, _ in
                        proxy.scrollTo(messages.last?.id)
                    }
                }
            }

            Spacer()

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Pergunta sobre o projecto…", text: $input, onCommit: {
                    Task { await send() }
                })
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(input.isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(input.isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var suggestions: [String] {
        ["Como faço deploy deste projecto?",
         "O que está por fazer?",
         "Que dependências devo actualizar?",
         "Explica a arquitectura do projecto"]
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(role: "user", content: text))
        isLoading = true

        let system = """
        Assistente técnico do projecto \(project.name).
        Stack: \(project.type.rawValue). Status: \(project.status.rawValue).
        Último commit: \(project.git.lastCommitMessage ?? "desconhecido").
        Responde em português, de forma directa e técnica.
        """
        let history = messages.dropLast().map { LLMMessage(role: $0.role, content: $0.content) }

        do {
            let reply: String
            if embeddedLLM.isReady {
                let fullPrompt = history.map { "\($0.role): \($0.content)" }.joined(separator: "\n") + "\nuser: \(text)"
                reply = try await embeddedLLM.generate(system: system, userMessage: fullPrompt)
            } else {
                reply = try await llmEngine.chatAboutProject(project, message: text, history: history)
            }
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            messages.append(ChatMessage(role: "assistant", content: "Erro: \(error.localizedDescription)"))
        }
        isLoading = false
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(message.content)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color(.controlBackgroundColor))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - README Section

struct ReadmeSection: View {
    let project: Project
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM
    @State private var readme: String = ""
    @State private var isGenerating: Bool = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if readme.isEmpty && !isGenerating {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Gerar README")
                        .font(.title3.bold())
                    Text("Gera um README.md completo baseado no contexto do projecto.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let error {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Button("Gerar README.md") { Task { await generate() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("A gerar README…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                HStack {
                    Text("README.md")
                        .font(.headline)
                    Spacer()
                    Button("Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(readme, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Guardar no projecto") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Button("Regerar") { Task { await generate() } }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                ScrollView {
                    Text(readme)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
    }

    private func generate() async {
        isGenerating = true
        error = nil
        do {
            if embeddedLLM.isReady {
                let system = "You are a senior developer. Write a clear, professional README.md in Markdown."
                let prompt = "Generate a README.md for: \(project.name), \(project.type.rawValue). Last commit: \(project.git.lastCommitMessage ?? "unknown"). Issues: \(project.issues.map { $0.message }.joined(separator: ", "))"
                readme = try await embeddedLLM.generate(system: system, userMessage: prompt)
            } else {
                readme = try await llmEngine.generateReadme(project)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isGenerating = false
    }

    private func save() {
        let path = project.path + "/README.md"
        try? readme.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
