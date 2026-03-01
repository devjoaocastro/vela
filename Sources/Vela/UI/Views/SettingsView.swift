import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM
    @State private var claudeKeyInput: String = ""
    @State private var openAIKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
    @State private var saved: Bool = false

    var body: some View {
        TabView {
            LLMSettingsTab(
                claudeKeyInput: $claudeKeyInput,
                openAIKeyInput: $openAIKeyInput,
                geminiKeyInput: $geminiKeyInput,
                saved: $saved
            )
            .tabItem { Label("LLM & AI", systemImage: "sparkles") }

            GeneralSettingsTab()
            .tabItem { Label("Geral", systemImage: "gear") }
        }
        .frame(width: 520, height: 460)
        .onAppear {
            claudeKeyInput = llmEngine.claudeKey
            openAIKeyInput = llmEngine.openAIKey
            geminiKeyInput = llmEngine.geminiKey
        }
    }
}

// MARK: - LLM Settings Tab

struct LLMSettingsTab: View {
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM
    @Binding var claudeKeyInput: String
    @Binding var openAIKeyInput: String
    @Binding var geminiKeyInput: String
    @Binding var saved: Bool

    var body: some View {
        Form {
            providerSection
            embeddedSection
            providerSpecificSection
            saveSection
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Sections as computed properties (avoids ViewBuilder ambiguity)

    @ViewBuilder
    private var providerSection: some View {
        Section("Provider Activo") {
            Picker("Provider", selection: $llmEngine.settings.activeProvider) {
                ForEach(LLMProviderType.allCases, id: \.self) { p in
                    Label(p.rawValue, systemImage: p.icon).tag(p)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: llmEngine.settings.activeProvider) { _, _ in
                llmEngine.saveSettings()
                Task { await llmEngine.checkAvailability() }
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(llmEngine.isAvailable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(llmEngine.isAvailable ? "Disponível" : "Não configurado")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var embeddedSection: some View {
        Section("Modelo Embutido (On-Device)") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: embeddedLLM.backendIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(embeddedLLM.isReady ? embeddedLLM.statusLabel : "Não detectado")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Text("Automático · Grátis · Offline")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if case .checking = embeddedLLM.state {
                    ProgressView().scaleEffect(0.8)
                } else if embeddedLLM.isReady {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button("Detectar") { Task { await embeddedLLM.detect() } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var providerSpecificSection: some View {
        switch llmEngine.settings.activeProvider {
        case .ollama:  ollamaSection
        case .claude:  claudeSection
        case .openAI:  openAISection
        case .gemini:  geminiSection
        }
    }

    @ViewBuilder
    private var ollamaSection: some View {
        Section("Ollama (Local)") {
            HStack {
                TextField("URL", text: $llmEngine.settings.ollamaURL)
                Button("Testar") { Task { await llmEngine.checkAvailability() } }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            Picker("Modelo", selection: $llmEngine.settings.ollamaModel) {
                ForEach(LLMProviderType.ollama.availableModels, id: \.self) { m in Text(m).tag(m) }
            }.pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var claudeSection: some View {
        Section("Anthropic (Claude)") {
            APIKeyField(label: "API Key", value: $claudeKeyInput, placeholder: "sk-ant-…")
            Picker("Modelo", selection: $llmEngine.settings.claudeModel) {
                ForEach(LLMProviderType.claude.availableModels, id: \.self) { m in Text(m).tag(m) }
            }.pickerStyle(.menu)
            Link("Obter API Key →", destination: URL(string: "https://console.anthropic.com")!)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var openAISection: some View {
        Section("OpenAI") {
            APIKeyField(label: "API Key", value: $openAIKeyInput, placeholder: "sk-…")
            Picker("Modelo", selection: $llmEngine.settings.openAIModel) {
                ForEach(LLMProviderType.openAI.availableModels, id: \.self) { m in Text(m).tag(m) }
            }.pickerStyle(.menu)
            Link("Obter API Key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var geminiSection: some View {
        Section("Google Gemini") {
            APIKeyField(label: "API Key", value: $geminiKeyInput, placeholder: "AIza…")
            Picker("Modelo", selection: $llmEngine.settings.geminiModel) {
                ForEach(LLMProviderType.gemini.availableModels, id: \.self) { m in Text(m).tag(m) }
            }.pickerStyle(.menu)
            Link("Obter API Key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        Section {
            HStack {
                Spacer()
                if saved {
                    Label("Guardado", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                }
                Button("Guardar") { saveAll() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func saveAll() {
        llmEngine.setClaudeKey(claudeKeyInput)
        llmEngine.setOpenAIKey(openAIKeyInput)
        llmEngine.setGeminiKey(geminiKeyInput)
        llmEngine.saveSettings()
        Task { await llmEngine.checkAvailability() }
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch: Bool = true
    @AppStorage("scanRootsCustom") private var scanRootsCustom: String = ""

    var body: some View {
        Form {
            Section("Scan") {
                Toggle("Scan automático ao abrir a app", isOn: $autoScanOnLaunch)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pastas adicionais").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $scanRootsCustom)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .padding(4)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("Uma pasta por linha. Ex: ~/code").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - API Key Field

struct APIKeyField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    @State private var isRevealed: Bool = false

    var body: some View {
        HStack {
            if isRevealed {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            } else {
                SecureField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }
            Button { isRevealed.toggle() } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary).font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
