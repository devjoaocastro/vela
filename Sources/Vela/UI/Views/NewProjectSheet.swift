import SwiftUI

// MARK: - GitHub Visibility

enum GitHubVisibility: String, CaseIterable {
    case `private` = "Privado"
    case `public`  = "Público"
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedType: ProjectType = .swiftApp
    @State private var basePath: String = "~/Desktop/Projetos"
    @State private var createGitRepo: Bool = true
    @State private var createWorkspace: Bool = false
    @State private var createGitHubRepo: Bool = false
    @State private var githubVisibility: GitHubVisibility = .private
    @State private var showGitHubConnect: Bool = false
    @State private var isCreating: Bool = false
    @State private var creationError: String? = nil

    private var githubToken: String? { KeychainStore.load(key: "vela.github.token") }
    private var isGitHubConnected: Bool { githubToken != nil }

    var finalPath: String {
        let expanded = (basePath as NSString).expandingTildeInPath
        let slug = name.isEmpty ? "novo-projecto"
            : name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        return expanded + "/" + slug
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Novo Projecto", systemImage: "plus.app")
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            Form {
                // Basic
                Section {
                    TextField("Nome do projecto", text: $name)
                    TextField("Descrição curta (opcional)", text: $description)
                }

                // Type
                Section("Tipo") {
                    Picker("Stack", selection: $selectedType) {
                        ForEach(ProjectType.allCases.filter { $0 != .unknown && $0 != .documentation }, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Location
                Section("Localização") {
                    HStack {
                        TextField("Pasta base", text: $basePath)
                        Button("Escolher…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                basePath = url.path
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text(finalPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                // Options
                Section("Opções") {
                    Toggle("Inicializar Git (git init)", isOn: $createGitRepo)
                    Toggle(isOn: $createWorkspace) {
                        Label("Criar Workspace VS Code", systemImage: "square.dashed")
                    }
                }

                // Services
                servicesSection
            }
            .formStyle(.grouped)

            if let error = creationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button {
                    Task { await createProject() }
                } label: {
                    if isCreating {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("A criar…")
                        }
                    } else {
                        Text("Criar Projecto")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(20)
        }
        .frame(width: 520, height: 580)
        .sheet(isPresented: $showGitHubConnect) {
            GitHubConnectSheet()
        }
    }

    // MARK: - Services Section

    @ViewBuilder
    private var servicesSection: some View {
        Section("Serviços") {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isGitHubConnected ? .primary : .tertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Criar Repositório GitHub")
                        .font(.system(size: 13))
                    Text(isGitHubConnected ? "Conta conectada" : "Conta não conectada")
                        .font(.caption)
                        .foregroundStyle(isGitHubConnected ? .green : .secondary)
                }

                Spacer()

                if isGitHubConnected {
                    if createGitHubRepo {
                        Picker("", selection: $githubVisibility) {
                            ForEach(GitHubVisibility.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .disabled(!createGitRepo)
                    }
                    Toggle("", isOn: $createGitHubRepo)
                        .disabled(!createGitRepo)
                        .labelsHidden()
                } else {
                    Button("Conectar") { showGitHubConnect = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func createProject() async {
        isCreating = true
        creationError = nil
        let fm = FileManager.default
        let path = finalPath

        do {
            try fm.createDirectory(atPath: path, withIntermediateDirectories: true)

            // README
            let readme = "# \(name)\n\n\(description.isEmpty ? "" : description + "\n")"
            try readme.write(toFile: path + "/README.md", atomically: true, encoding: .utf8)

            // .gitignore
            try gitignoreFor(selectedType).write(toFile: path + "/.gitignore", atomically: true, encoding: .utf8)

            // VS Code Workspace
            if createWorkspace {
                let slug = URL(fileURLWithPath: path).lastPathComponent
                let ws = "{\n    \"folders\": [\n        { \"path\": \".\" }\n    ],\n    \"settings\": {\n        \"editor.formatOnSave\": true\n    }\n}\n"
                try ws.write(toFile: path + "/\(slug).code-workspace", atomically: true, encoding: .utf8)
            }

            // Git init
            if createGitRepo {
                shell("git init '\(path)'")
                shell("cd '\(path)' && git add -A && git commit -m 'chore: initial commit'")
            }

            // GitHub repo
            if createGitHubRepo, createGitRepo, let token = githubToken {
                await createGitHubRepository(repoName: URL(fileURLWithPath: path).lastPathComponent,
                                             token: token, localPath: path)
            }

        } catch {
            creationError = error.localizedDescription
            isCreating = false
            return
        }

        await appState.scanProjects()
        if let project = appState.projects.first(where: { $0.path == path }) {
            appState.openInEditor(project)
            appState.selectedProject = project
        }

        isCreating = false
        dismiss()
    }

    // MARK: - GitHub API

    private func createGitHubRepository(repoName: String, token: String, localPath: String) async {
        guard let url = URL(string: "https://api.github.com/user/repos") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": repoName,
            "description": description,
            "private": githubVisibility == .private,
            "auto_init": false
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cloneURL = json["clone_url"] as? String else { return }
        shell("git -C '\(localPath)' remote add origin '\(cloneURL)'")
        shell("git -C '\(localPath)' branch -M main")
        shell("git -C '\(localPath)' push -u origin main")
    }

    // MARK: - Shell

    @discardableResult
    private func shell(_ cmd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    private func gitignoreFor(_ type: ProjectType) -> String {
        switch type {
        case .swiftApp:
            return ".build/\n*.xcuserstate\nDerivedData/\n.DS_Store\n"
        case .reactNative, .nextJS, .node:
            return "node_modules/\n.next/\ndist/\n.env\n.env.local\n.DS_Store\n"
        case .python:
            return "venv/\n.venv/\n__pycache__/\n*.pyc\n.env\n.DS_Store\n"
        case .flutter:
            return ".dart_tool/\nbuild/\n.flutter-plugins\n.DS_Store\n"
        case .rust:
            return "target/\n.env\n.DS_Store\n"
        default:
            return ".DS_Store\n.env\n"
        }
    }
}

// MARK: - GitHub Connect Sheet

struct GitHubConnectSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var token: String = ""
    @State private var isVerifying: Bool = false
    @State private var error: String? = nil
    @State private var connectedUser: String? = nil

    private var existingToken: String? { KeychainStore.load(key: "vela.github.token") }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Conectar GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.title3.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                if let user = connectedUser {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conectado como **\(user)**")
                            Text("Token guardado no Keychain.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("Desconectar") {
                        KeychainStore.delete(key: "vela.github.token")
                        connectedUser = nil; token = ""
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                } else {
                    Text("Cria um **Personal Access Token** com permissão `repo` e cola aqui.")
                        .font(.callout).foregroundStyle(.secondary)

                    Link("Criar token no GitHub →",
                         destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Vela")!)
                    .font(.callout)

                    SecureField("ghp_xxxx…", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    if let err = error {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()
                Button("Fechar") { dismiss() }.buttonStyle(.bordered)
                if connectedUser == nil {
                    Button {
                        Task { await verifyAndSave() }
                    } label: {
                        if isVerifying {
                            HStack(spacing: 6) { ProgressView().scaleEffect(0.7); Text("A verificar…") }
                        } else { Text("Conectar") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
        .onAppear {
            if let t = existingToken { token = t; Task { await loadUser(t) } }
        }
    }

    private func verifyAndSave() async {
        isVerifying = true; error = nil
        let t = token.trimmingCharacters(in: .whitespaces)
        if let user = await fetchUser(token: t) {
            KeychainStore.save(key: "vela.github.token", value: t)
            connectedUser = user
        } else {
            error = "Token inválido ou sem permissões repo. Verifica e tenta novamente."
        }
        isVerifying = false
    }

    private func loadUser(_ t: String) async {
        connectedUser = await fetchUser(token: t)
    }

    private func fetchUser(token: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/user") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let login = json["login"] as? String else { return nil }
        return login
    }
}
