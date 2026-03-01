import Foundation

// MARK: - Security Finding

struct SecurityFinding: Identifiable {
    let id = UUID()
    let severity: Severity
    let category: Category
    let title: String
    let detail: String
    let recommendation: String

    enum Severity: Int, Comparable {
        case critical = 3, high = 2, medium = 1, info = 0
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

        var icon: String {
            switch self {
            case .critical: return "xmark.octagon.fill"
            case .high:     return "exclamationmark.triangle.fill"
            case .medium:   return "exclamationmark.circle.fill"
            case .info:     return "info.circle.fill"
            }
        }
        var color: String {
            switch self {
            case .critical: return "#EF4444"
            case .high:     return "#F97316"
            case .medium:   return "#F59E0B"
            case .info:     return "#3B82F6"
            }
        }
        var label: String {
            switch self {
            case .critical: return "Crítico"
            case .high:     return "Alto"
            case .medium:   return "Médio"
            case .info:     return "Info"
            }
        }
    }

    enum Category: String {
        case secrets      = "Segredos"
        case gitHygiene   = "Git"
        case dependencies = "Dependências"
        case structure    = "Estrutura"
        case bestPractice = "Boas Práticas"
    }
}

// MARK: - Security Scanner

actor SecurityScanner {

    private let secretPatterns: [(label: String, pattern: String)] = [
        ("Chave Anthropic",  "sk-ant-[a-zA-Z0-9\\-_]{20,}"),
        ("Chave OpenAI",     "sk-[a-zA-Z0-9]{32,}"),
        ("AWS Access Key",   "AKIA[0-9A-Z]{16}"),
        ("Token GitHub",     "gh[pousr]_[a-zA-Z0-9]{36,}"),
        ("Chave privada",    "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
        ("DB URL com senha", "(postgres|mysql|mongodb)://[^@\\s]+:[^@\\s]+@"),
        ("Stripe Key",       "(sk|pk)_(live|test)_[a-zA-Z0-9]{24,}"),
    ]

    func scan(_ project: Project) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let url = URL(fileURLWithPath: project.path)
        findings += await checkTrackedSensitiveFiles(url)
        findings += await checkSecretsInCode(url, type: project.type)
        findings += await checkGitHistorySecrets(url)
        findings += await checkGitignoreCompleteness(url, type: project.type)
        findings += await checkStructure(url)
        return findings.sorted { $0.severity > $1.severity }
    }

    // MARK: - Tracked Sensitive Files

    private func checkTrackedSensitiveFiles(_ url: URL) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        guard let tracked = shell("git -C \(url.path.quoted) ls-files 2>/dev/null") else { return [] }
        let files = tracked.components(separatedBy: "\n").filter { !$0.isEmpty }
        let dangerExts  = Set(["pem", "key", "p12", "pfx", "cer", "keystore"])
        let dangerNames = Set(["id_rsa", "id_ed25519", "id_ecdsa", "secrets.json",
                               "credentials.json", "google-services.json", "GoogleService-Info.plist"])
        for file in files {
            let name = URL(fileURLWithPath: file).lastPathComponent
            let ext  = URL(fileURLWithPath: file).pathExtension.lowercased()
            if dangerExts.contains(ext) {
                findings.append(.init(severity: .critical, category: .secrets,
                    title: "Chave criptográfica no git",
                    detail: "'\(file)' está tracked e parece uma chave privada.",
                    recommendation: "git rm --cached \(file) && echo '\(file)' >> .gitignore"))
            } else if dangerNames.contains(name.lowercased()) || name == ".env" || name.hasPrefix(".env.") {
                findings.append(.init(severity: .critical, category: .secrets,
                    title: "Ficheiro sensível no git",
                    detail: "'\(file)' não deve estar no repositório.",
                    recommendation: "git rm --cached \(file) e adiciona ao .gitignore"))
            }
        }
        return findings
    }

    // MARK: - Secrets in Code

    private func checkSecretsInCode(_ url: URL, type: ProjectType) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let extsMap: [ProjectType: String] = [
            .swiftApp: "swift", .reactNative: "js,ts,tsx,jsx",
            .nextJS: "js,ts,tsx,jsx", .node: "js,ts",
            .python: "py", .flutter: "dart", .rust: "rs"
        ]
        let exts = extsMap[type] ?? "swift,js,ts,py"

        for (label, pattern) in secretPatterns {
            let cmd = "grep -rn --include='*.{\(exts)}' -E '\(pattern)' \(url.path.quoted) 2>/dev/null | grep -v '.git' | head -3"
            if let out = shell(cmd), !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let count = out.components(separatedBy: "\n").filter { !$0.isEmpty }.count
                findings.append(.init(severity: .critical, category: .secrets,
                    title: "\(label) hardcoded no código",
                    detail: "Padrão encontrado em \(count) linha(s). Nunca commites credenciais.",
                    recommendation: "Usa variáveis de ambiente ou o Keychain. Regenera as credenciais imediatamente."))
            }
        }
        return findings
    }

    // MARK: - Git History

    private func checkGitHistorySecrets(_ url: URL) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        guard shell("git -C \(url.path.quoted) rev-parse HEAD 2>/dev/null") != nil else { return [] }
        let markers = ["sk-ant-", "AKIA", "-----BEGIN PRIVATE KEY", "sk-live-"]
        for marker in markers {
            let cmd = "git -C \(url.path.quoted) log --all -20 -S'\(marker)' --oneline 2>/dev/null"
            if let out = shell(cmd), !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(.init(severity: .high, category: .secrets,
                    title: "Possível segredo no histórico git",
                    detail: "Padrão '\(marker)' encontrado em commits anteriores.",
                    recommendation: "Usa BFG Repo Cleaner para limpar o histórico. Revoga e regenera as credenciais."))
            }
        }
        return findings
    }

    // MARK: - .gitignore Completeness

    private func checkGitignoreCompleteness(_ url: URL, type: ProjectType) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let path = url.appendingPathComponent(".gitignore")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        let content = (try? String(contentsOf: path)) ?? ""

        let required: [ProjectType: [String]] = [
            .swiftApp:    [".build/", "DerivedData"],
            .reactNative: ["node_modules", ".env"],
            .nextJS:      ["node_modules", ".next", ".env.local"],
            .node:        ["node_modules", ".env"],
            .python:      ["venv", "__pycache__", ".env"],
            .flutter:     [".dart_tool", "build"],
            .rust:        ["target/"],
        ]
        if let checks = required[type] {
            for entry in checks where !content.contains(entry) {
                findings.append(.init(severity: .medium, category: .gitHygiene,
                    title: ".gitignore incompleto",
                    detail: "'\(entry)' não está no .gitignore.",
                    recommendation: "Adiciona '\(entry)' ao .gitignore."))
            }
        }
        if !content.contains(".env") {
            findings.append(.init(severity: .high, category: .gitHygiene,
                title: ".env não protegido",
                detail: "Ficheiros .env não estão no .gitignore.",
                recommendation: "Adiciona '.env\\n.env.*\\n!.env.example' ao .gitignore."))
        }
        return findings
    }

    // MARK: - Structure

    private func checkStructure(_ url: URL) async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let fm = FileManager.default
        func has(_ f: String) -> Bool { fm.fileExists(atPath: url.appendingPathComponent(f).path) }

        if !has("LICENSE") && !has("LICENSE.md") && !has("LICENSE.txt") {
            findings.append(.init(severity: .info, category: .structure,
                title: "Sem licença",
                detail: "Sem ficheiro LICENSE o projecto é 'All Rights Reserved' por defeito.",
                recommendation: "Adiciona um LICENSE (MIT, Apache 2.0, etc.)"))
        }
        if has(".vscode/launch.json") {
            let launch = (try? String(contentsOf: url.appendingPathComponent(".vscode/launch.json"))) ?? ""
            if launch.contains("\"env\"") {
                findings.append(.init(severity: .medium, category: .secrets,
                    title: "Env vars em launch.json",
                    detail: ".vscode/launch.json pode conter variáveis sensíveis.",
                    recommendation: "Verifica se .vscode/launch.json está no .gitignore."))
            }
        }
        return findings
    }

    // MARK: - Shell Helper

    private func shell(_ cmd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

private extension String {
    var quoted: String { "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'" }
}
