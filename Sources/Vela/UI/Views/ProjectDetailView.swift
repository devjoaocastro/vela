import SwiftUI
import WebKit

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM
    @State private var selectedTab: DetailTab = .overview

    enum DetailTab: String, CaseIterable {
        case overview  = "Overview"
        case explorer  = "Explorer"
        case security  = "Segurança"
        case browser   = "Browser"
        case ai        = "AI"
        case notes     = "Notas"
    }

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(project: $project)
            Divider()
            tabBar
            Divider()
            tabContent
        }
        .background(.windowBackground)
        .navigationTitle(project.name)
        // Keyboard shortcuts ⌘1–6 for tabs
        .keyboardShortcut("1", modifiers: .command)  // handled below via onKeyPress workaround
        .background(tabKeyboardShortcuts)
    }

    // Invisible buttons to capture ⌘1-6
    private var tabKeyboardShortcuts: some View {
        Group {
            ForEach(Array(DetailTab.allCases.enumerated()), id: \.offset) { idx, tab in
                Button("") { selectedTab = tab }
                    .keyboardShortcut(KeyEquivalent(Character(String(idx + 1))), modifiers: .command)
                    .hidden()
            }
        }
    }

    // MARK: - Native Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 36)
        .background(.bar)
    }

    private func tabButton(_ tab: DetailTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selectedTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tabIcon(tab))
                    .font(.system(size: 11, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))

                // Badges
                if tab == .security && !project.issues.isEmpty {
                    badge(count: project.issues.count, color: .red)
                }
                if tab == .ai {
                    Circle()
                        .fill(embeddedLLM.isReady ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                selectedTab == tab
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear
            )
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .overlay(alignment: .bottom) {
                if selectedTab == tab {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func badge(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .browser:
            let githubURL = project.git.remoteURL?
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
                ?? "https://www.google.com"
            BrowserPanel(initialURL: githubURL)
        case .explorer:
            // Explorer manages its own scrolling
            ExplorerView(project: project)
        default:
            ScrollView {
                switch selectedTab {
                case .overview:  XRayView(project: project)
                case .security:  SecurityView(project: project)
                case .ai:        AIView(project: project)
                case .notes:     NotesView(project: $project)
                default:         EmptyView()
                }
            }
        }
    }

    private func tabIcon(_ tab: DetailTab) -> String {
        switch tab {
        case .overview:  return "chart.bar.xaxis"
        case .explorer:  return "folder.badge.magnifyingglass"
        case .security:  return "lock.shield"
        case .browser:   return "globe"
        case .ai:        return "sparkles"
        case .notes:     return "pencil"
        }
    }
}

// MARK: - Header

struct ProjectHeaderView: View {
    @Binding var project: Project
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: project.type.color).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: project.type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: project.type.color))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.title2.bold())
                    // Clickable status badge → quick-edit menu
                    Menu {
                        ForEach(ProjectStatus.allCases, id: \.self) { s in
                            Button {
                                var p = project
                                p.status = s
                                project = p
                                appState.update(p)
                            } label: {
                                Label(s.rawValue, systemImage: s.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: project.status.color))
                                .frame(width: 6, height: 6)
                            Text(project.status.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: project.status.color))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(hex: project.status.color).opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: project.status.color).opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Alterar estado do projecto")
                }
                Text(project.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let remote = project.git.remoteURL {
                    Text(remote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Native ControlGroup for primary actions
            ControlGroup {
                Button(action: { appState.openInEditor(project) }) {
                    Label("Editor", systemImage: "curlybraces")
                }
                .help("Abrir no Editor")

                Button(action: { appState.revealInFinder(project) }) {
                    Label("Finder", systemImage: "folder")
                }
                .help("Mostrar no Finder")

                Menu {
                    if let remote = project.git.remoteURL {
                        let web = remote
                            .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                            .replacingOccurrences(of: ".git", with: "")
                        if let url = URL(string: web) {
                            Link("Abrir no GitHub", destination: url)
                        }
                    }
                    Divider()
                    Button("Copiar Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(project.path, forType: .string)
                    }
                } label: {
                    Label("Mais", systemImage: "ellipsis")
                }
                .help("Mais opções")
            }
            .controlGroupStyle(.navigation)
        }
        .padding(20)
    }
}

// MARK: - Overview Tab

struct RecentCommit: Identifiable {
    let id = UUID()
    let hash: String
    let message: String
    let author: String
    let relativeDate: String
}

struct XRayView: View {
    let project: Project
    @State private var recentCommits: [RecentCommit] = []

    var body: some View {
        VStack(spacing: 16) {

            // ── Stats ribbon ──────────────────────────────────────────────
            statsRibbon

            // ── Recent activity ───────────────────────────────────────────
            if project.git.hasGit && !recentCommits.isEmpty {
                recentActivitySection
            }

            // ── Cards grid ────────────────────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                gitCard
                discoCard
                vitalidadeCard
                stackCard
            }

            // ── Language bar ──────────────────────────────────────────────
            if !project.languages.isEmpty {
                languagesSection
            }
        }
        .padding(20)
        .task(id: project.path) { await loadCommits() }
    }

    // MARK: - Stats Ribbon

    @ViewBuilder
    private var statsRibbon: some View {
        HStack(spacing: 0) {
            if project.git.hasGit {
                statBadge(icon: "clock", label: "Último commit",
                          value: project.git.lastCommitDate.map { formatRelative($0) } ?? "—", color: .blue)
                Divider().frame(height: 36).padding(.horizontal, 2)
                statBadge(icon: "arrow.triangle.branch", label: "Branch",
                          value: project.git.activeBranch ?? "—", color: .teal)
                Divider().frame(height: 36).padding(.horizontal, 2)
                statBadge(icon: "number", label: "Commits",
                          value: "\(project.git.totalCommits)", color: .teal)
                if project.git.uncommittedChanges > 0 {
                    Divider().frame(height: 36).padding(.horizontal, 2)
                    statBadge(icon: "exclamationmark.triangle.fill", label: "Por commitar",
                              value: "\(project.git.uncommittedChanges)", color: .orange)
                }
            } else {
                statBadge(icon: "folder", label: "Tipo",
                          value: project.type.rawValue, color: Color(hex: project.type.color))
                Divider().frame(height: 36).padding(.horizontal, 2)
                statBadge(icon: "waveform.path.ecg", label: "Vitalidade",
                          value: "\(project.vitalityScore)/100", color: vitalityColor)
                Divider().frame(height: 36).padding(.horizontal, 2)
                statBadge(icon: "doc.text", label: "Docs",
                          value: "\(project.markdownFiles.count) .md", color: .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                sectionLabel("Actividade Recente", icon: "clock.arrow.circlepath", color: .blue)
                Spacer()
                Text("\(recentCommits.count) commits")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Commits
            VStack(spacing: 0) {
                ForEach(Array(recentCommits.prefix(8).enumerated()), id: \.element.id) { idx, commit in
                    commitRow(commit)
                    if idx < min(7, recentCommits.count - 1) {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
    }

    private func commitRow(_ commit: RecentCommit) -> some View {
        HStack(spacing: 10) {
            // Author avatar
            ZStack {
                Circle()
                    .fill(avatarGradient(commit.author))
                    .frame(width: 26, height: 26)
                Text(initials(commit.author))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(commit.hash)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(commit.author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(commit.relativeDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            // Commit type dot
            commitTypeDot(commit.message)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func commitTypeDot(_ msg: String) -> some View {
        let lower = msg.lowercased()
        let color: Color
        if lower.hasPrefix("fix") || lower.contains("bug") || lower.hasPrefix("hotfix") {
            color = .red
        } else if lower.hasPrefix("feat") || lower.hasPrefix("add") || lower.hasPrefix("new") {
            color = .green
        } else if lower.hasPrefix("refactor") || lower.hasPrefix("chore") || lower.hasPrefix("clean") {
            color = .secondary
        } else if lower.hasPrefix("doc") || lower.hasPrefix("readme") {
            color = .cyan
        } else {
            color = .accentColor
        }
        return Circle().fill(color).frame(width: 6, height: 6)
    }

    // MARK: - Cards

    private var gitCard: some View {
        OverviewCard(title: "Git", icon: "arrow.triangle.branch", accent: .blue) {
            if project.git.hasGit {
                if let msg = project.git.lastCommitMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .padding(.bottom, 2)
                }
                OverviewRow(label: "Branch", value: project.git.activeBranch ?? "—")
                OverviewRow(label: "Remote", value: project.git.hasRemote ? "Conectado" : "Sem remote",
                            valueColor: project.git.hasRemote ? .green : .secondary)
                if project.git.uncommittedChanges > 0 {
                    OverviewRow(label: "Pendente", value: "\(project.git.uncommittedChanges) ficheiros",
                                valueColor: .orange)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("Sem repositório Git")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private var discoCard: some View {
        OverviewCard(title: "Disco", icon: "internaldrive", accent: .green) {
            if project.disk.totalBytes > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(project.disk.formattedTotal)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
                OverviewRow(label: "Código", value: project.disk.formattedCode, valueColor: .green)
                if project.disk.dependencyBytes > 0 {
                    OverviewRow(label: "Dependências", value: project.disk.formattedDeps, valueColor: .orange)
                }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        let total = max(project.disk.totalBytes, 1)
                        let codeR = CGFloat(project.disk.codeBytes) / CGFloat(total)
                        let depR  = CGFloat(project.disk.dependencyBytes) / CGFloat(total)
                        Capsule().fill(.green).frame(width: max(4, geo.size.width * codeR))
                        if depR > 0 {
                            Capsule().fill(.orange).frame(width: max(4, geo.size.width * depR))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 5)
                .padding(.top, 4)
            } else {
                Text("—").foregroundStyle(.tertiary).font(.caption)
            }
        }
    }

    private var vitalidadeCard: some View {
        OverviewCard(title: "Vitalidade", icon: "waveform.path.ecg", accent: vitalityColor) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(vitalityColor.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(project.vitalityScore) / 100)
                        .stroke(vitalityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.6), value: project.vitalityScore)
                    VStack(spacing: 0) {
                        Text("\(project.vitalityScore)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(vitalityColor)
                        Text("/100")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vitalityLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(vitalityColor)
                    if let days = project.git.daysSinceLastCommit {
                        Text(days == 0 ? "Commit hoje" : "\(days) dias sem commits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if project.git.uncommittedChanges > 0 {
                        Label("\(project.git.uncommittedChanges) pendentes", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var stackCard: some View {
        OverviewCard(title: "Stack", icon: "square.stack.3d.up", accent: Color(hex: project.type.color)) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: project.type.color).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: project.type.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: project.type.color))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(URL(fileURLWithPath: project.path).lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 2)
            if !project.markdownFiles.isEmpty {
                OverviewRow(label: "Docs", value: "\(project.markdownFiles.count) ficheiro(s)")
            }
            OverviewRow(label: "Problemas",
                        value: project.issues.isEmpty ? "Nenhum" : "\(project.issues.count)",
                        valueColor: project.issues.isEmpty ? .green : .orange)
            if !project.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(project.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Languages

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Linguagens", icon: "chevron.left.forwardslash.chevron.right", color: .blue)

            let sorted = project.languages.sorted { $0.value > $1.value }.prefix(8)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(sorted), id: \.key) { lang, pct in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(langColor(lang))
                            .frame(width: max(4, geo.size.width * CGFloat(pct / 100)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            FlowLayout(spacing: 10) {
                ForEach(Array(sorted), id: \.key) { lang, pct in
                    HStack(spacing: 4) {
                        Circle().fill(langColor(lang)).frame(width: 7, height: 7)
                        Text(lang).font(.caption.weight(.medium))
                        Text("\(Int(pct))%").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
    }

    // MARK: - Async

    private func loadCommits() async {
        guard project.git.hasGit else { return }
        let commits: [RecentCommit] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                proc.arguments = ["-C", project.path, "log", "--format=%h|%s|%an|%ar", "-15"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()
                try? proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let parsed = output.components(separatedBy: "\n").compactMap { line -> RecentCommit? in
                    guard !line.isEmpty else { return nil }
                    let parts = line.components(separatedBy: "|")
                    guard parts.count >= 4 else { return nil }
                    return RecentCommit(
                        hash: parts[0],
                        message: parts.dropFirst().dropLast(2).joined(separator: "|"),
                        author: parts[parts.count - 2],
                        relativeDate: parts[parts.count - 1]
                    )
                }
                continuation.resume(returning: parsed)
            }
        }
        recentCommits = commits
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    private func statBadge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private func avatarGradient(_ name: String) -> LinearGradient {
        let pairs: [(Color, Color)] = [
            (.blue, .cyan), (.teal, .green), (.orange, .yellow),
            (.pink, .red), (.indigo, .blue), (.mint, .teal)
        ]
        let idx = abs(name.hashValue) % pairs.count
        return LinearGradient(colors: [pairs[idx].0, pairs[idx].1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func langColor(_ lang: String) -> Color {
        switch lang {
        case "Swift":       return Color(hex: "#F05138")
        case "TypeScript":  return Color(hex: "#3178C6")
        case "JavaScript":  return Color(hex: "#F1E05A")
        case "Python":      return Color(hex: "#3572A5")
        case "Rust":        return Color(hex: "#CE4A00")
        case "Dart":        return Color(hex: "#00B4AB")
        case "Go":          return Color(hex: "#00ADD8")
        case "Ruby":        return Color(hex: "#CC342D")
        case "Kotlin":      return Color(hex: "#7F52FF")
        case "Java":        return Color(hex: "#B07219")
        case "CSS", "SCSS": return Color(hex: "#563D7C")
        case "HTML":        return Color(hex: "#E34F26")
        case "Vue":         return Color(hex: "#41B883")
        case "C++":         return Color(hex: "#F34B7D")
        case "C", "C/C++":  return Color(hex: "#555555")
        case "Shell":       return Color(hex: "#89E051")
        case "Objective-C": return Color(hex: "#438EFF")
        default:            return Color.secondary
        }
    }

    private var vitalityColor: Color {
        switch project.vitalityScore {
        case 70...: return .green
        case 40...69: return .orange
        default: return .red
        }
    }

    private var vitalityLabel: String {
        switch project.vitalityScore {
        case 70...: return "Vivo e activo"
        case 40...69: return "Adormecido"
        default: return "Precisa de atenção"
        }
    }

    private func formatRelative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = .current
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reusable Components

struct OverviewCard<Content: View>: View {
    let title: String
    let icon: String
    var accent: Color = .blue
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(accent.opacity(0.12))
                        .frame(width: 20, height: 20)
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
    }
}

struct OverviewRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Explorer Tab (File tree + README + Export)

struct ExplorerView: View {
    let project: Project
    @State private var section: ExplorerSection = .readme
    @State private var readmeHeight: CGFloat = 400
    @State private var fileNodes: [FileNode] = []
    @State private var isLoadingTree = false

    enum ExplorerSection: String, CaseIterable {
        case readme  = "README"
        case files   = "Ficheiros"
        case links   = "Links"
    }

    private var readmeContent: String? {
        // Try common readme filenames case-insensitively
        let candidates = ["README.md", "readme.md", "README.MD", "Readme.md",
                          "README", "readme.rst", "README.rst", "readme.txt",
                          "README.txt", "readme.markdown", "README.markdown"]
        for name in candidates {
            let path = project.path + "/" + name
            if let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
                return content
            }
        }
        // Fallback: case-insensitive scan of root directory
        if let items = try? FileManager.default.contentsOfDirectory(atPath: project.path) {
            if let readme = items.first(where: { $0.lowercased().hasPrefix("readme") }) {
                let path = project.path + "/" + readme
                if let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
                    return content
                }
            }
        }
        return project.markdownFiles.first(where: {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased().hasPrefix("readme")
        }).flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab/action bar ────────────────────────────────────────────
            HStack(spacing: 10) {
                Picker("", selection: $section) {
                    ForEach(ExplorerSection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Spacer()

                Button { exportProjectBrief() } label: {
                    Label("Exportar .md", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Exportar resumo do projecto como Markdown")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // ── Content ───────────────────────────────────────────────────
            switch section {
            case .readme:  readmeSection
            case .files:   filesSection
            case .links:   linksSection
            }
        }
    }

    // MARK: - README

    @ViewBuilder
    private var readmeSection: some View {
        ScrollView {
            if let content = readmeContent {
                VStack(alignment: .leading, spacing: 12) {
                    // Header bar
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("README.md")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            let path = project.markdownFiles.first(where: {
                                URL(fileURLWithPath: $0).lastPathComponent.lowercased() == "readme.md"
                            }) ?? project.path + "/README.md"
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        } label: {
                            Label("Abrir", systemImage: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Abrir no editor")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 0.5))

                    MarkdownWebView(markdown: content, height: $readmeHeight)
                        .frame(height: readmeHeight)
                }
                .padding(16)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("Sem README.md")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Cria um README.md na raiz do projecto\npara documentar o teu trabalho.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Button("Criar README.md") {
                        let path = project.path + "/README.md"
                        let content = "# \(project.name)\n\n\(project.description)\n"
                        try? content.write(toFile: path, atomically: true, encoding: .utf8)
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                .padding(60)
            }
        }
    }

    // MARK: - File Tree

    @ViewBuilder
    private var filesSection: some View {
        if isLoadingTree {
            ProgressView("A carregar ficheiros…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if fileNodes.isEmpty {
            ProgressView("A carregar ficheiros…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { loadTree() }
        } else {
            List(fileNodes, children: \.optChildren) { node in
                FileNodeRow(node: node)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var linksSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if project.links.isEmpty && !project.git.hasGit {
                    VStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Sem links")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Adiciona links úteis na tab Notas.")
                            .font(.callout).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    if !project.links.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Links", systemImage: "link")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(project.links) { link in
                                HStack(spacing: 10) {
                                    Image(systemName: link.icon)
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 13))
                                        .frame(width: 18)
                                    Text(link.label)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    if let url = URL(string: link.url) {
                                        Link(link.url, destination: url)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 0.5))
                            }
                        }
                    }

                    if project.git.hasGit, let msg = project.git.lastCommitMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Último commit", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "chevron.right.2")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg)
                                        .font(.system(.callout, design: .monospaced))
                                    if let date = project.git.lastCommitDate {
                                        Text(date.formatted(date: .long, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 0.5))
                        }
                    }

                    if !project.markdownFiles.isEmpty {
                        let otherDocs = project.markdownFiles.filter {
                            URL(fileURLWithPath: $0).lastPathComponent.lowercased() != "readme.md"
                        }
                        if !otherDocs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Documentos", systemImage: "doc.text")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(otherDocs, id: \.self) { path in
                                    MarkdownFileRow(path: path)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - File tree loader

    private func loadTree() {
        guard !isLoadingTree else { return }
        isLoadingTree = true
        let projectPath = project.path
        DispatchQueue.global(qos: .userInitiated).async {
            let nodes = Self.buildTree(at: URL(fileURLWithPath: projectPath), depth: 0)
            DispatchQueue.main.async {
                fileNodes = nodes
                isLoadingTree = false
            }
        }
    }

    private static let skipDirsTree: Set<String> = [
        "node_modules", ".git", ".build", "build", "dist", ".next",
        "DerivedData", "venv", ".venv", "__pycache__", ".gradle", ".idea", ".vs"
    ]

    static func buildTree(at url: URL, depth: Int) -> [FileNode] {
        guard depth < 6 else { return [] }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items
            .filter { !skipDirsTree.contains($0.lastPathComponent) }
            .sorted {
                let aD = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bD = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aD != bD { return aD }
                return $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .map { item in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    let ch = buildTree(at: item, depth: depth + 1)
                    return FileNode(url: item, name: item.lastPathComponent, isDirectory: true, children: ch)
                }
                return FileNode(url: item, name: item.lastPathComponent, isDirectory: false, children: nil)
            }
    }

    // MARK: - Export

    private func exportProjectBrief() {
        var md = "# \(project.name)\n\n"
        if !project.description.isEmpty { md += "> \(project.description)\n\n" }
        md += "| Campo | Valor |\n|---|---|\n"
        md += "| Tipo | \(project.type.rawValue) |\n"
        md += "| Estado | \(project.status.rawValue) |\n"
        md += "| Path | `\(project.path)` |\n"
        if project.git.hasGit {
            if let b = project.git.activeBranch { md += "| Branch | `\(b)` |\n" }
            md += "| Commits | \(project.git.totalCommits) |\n"
        }
        md += "\n"
        if !project.notes.isEmpty { md += "## Notas\n\n\(project.notes)\n\n" }
        if !project.links.isEmpty {
            md += "## Links\n\n"
            project.links.forEach { md += "- [\($0.label)](\($0.url))\n" }
            md += "\n"
        }
        if !project.tags.isEmpty {
            md += "## Tags\n\n"
            md += project.tags.map { "`\($0)`" }.joined(separator: " ") + "\n\n"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(project.name)-brief.md"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Exportar resumo do projecto"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - File Node model

struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?

    /// nil = leaf (List won't show disclosure arrow). Empty array = empty folder.
    var optChildren: [FileNode]? {
        guard isDirectory else { return nil }
        return children ?? []
    }
}

// MARK: - File Node Row

struct FileNodeRow: View {
    let node: FileNode

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 16, alignment: .center)
            Text(node.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            if !node.isDirectory, let size = fileSize {
                Text(size)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { NSWorkspace.shared.open(node.url) }
        .contextMenu {
            Button("Abrir") { NSWorkspace.shared.open(node.url) }
            Button("Mostrar no Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            Divider()
            Button("Copiar Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
        }
    }

    private var icon: String {
        if node.isDirectory { return "folder.fill" }
        switch node.url.pathExtension.lowercased() {
        case "md", "markdown":                   return "doc.text.fill"
        case "swift":                            return "swift"
        case "js", "jsx", "mjs":                return "doc.badge.gearshape"
        case "ts", "tsx":                        return "doc.badge.gearshape.fill"
        case "py":                               return "doc.plaintext"
        case "json":                             return "curlybraces"
        case "yaml", "yml", "toml":              return "list.bullet.indent"
        case "sh", "bash", "zsh":               return "terminal"
        case "html", "htm":                      return "globe"
        case "css", "scss", "sass":              return "paintbrush.pointed.fill"
        case "png", "jpg", "jpeg", "gif", "svg", "ico", "webp": return "photo"
        case "pdf":                              return "doc.richtext.fill"
        case "rs":                               return "gearshape.2"
        case "go":                               return "arrow.forward.circle"
        case "rb":                               return "circle.hexagongrid"
        case "kt", "kts":                        return "k.circle"
        case "dart":                             return "arrowshape.forward"
        case "vue", "svelte":                    return "wand.and.stars"
        case "lock", "gitignore", "gitattributes": return "lock.doc"
        case "txt":                              return "text.alignleft"
        default:                                 return "doc"
        }
    }

    private var iconColor: Color {
        if node.isDirectory { return Color(hex: "#4A9EF5") }
        switch node.url.pathExtension.lowercased() {
        case "swift":               return Color(hex: "#FA7343")
        case "ts", "tsx":           return Color(hex: "#3178C6")
        case "js", "jsx":           return Color(hex: "#F0DB4F")
        case "py":                  return Color(hex: "#3572A5")
        case "md", "markdown":      return Color(hex: "#0EA5E9")
        case "json":                return Color(hex: "#F97316")
        case "yaml", "yml", "toml": return Color(hex: "#E11D48")
        case "sh", "bash", "zsh":   return Color(hex: "#22D3EE")
        case "html", "htm":         return Color(hex: "#E34F26")
        case "css", "scss":         return Color(hex: "#2965F1")
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .green
        case "rs":                  return Color(hex: "#CE4A00")
        case "go":                  return Color(hex: "#00ADD8")
        case "rb":                  return Color(hex: "#CC342D")
        case "kt":                  return Color(hex: "#7F52FF")
        default:                    return .secondary
        }
    }

    private var fileSize: String? {
        guard let size = try? node.url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct MarkdownFileRow: View {
    let path: String
    var body: some View {
        Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill").foregroundStyle(.blue).font(.system(size: 12))
                Text(URL(fileURLWithPath: path).lastPathComponent).font(.callout).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Issues Tab

struct IssuesView: View {
    let project: Project
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if project.issues.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundStyle(.green)
                        Text("Sem problemas detectados").font(.headline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    Spacer()
                }
            } else {
                ForEach(project.issues) { issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: issue.severity.icon)
                            .foregroundStyle(issueColor(issue.severity))
                            .font(.system(size: 14))
                        Text(issue.message).font(.callout)
                        Spacer()
                    }
                    .padding(12)
                    .background(issueColor(issue.severity).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func issueColor(_ s: ProjectIssue.IssueSeverity) -> Color {
        switch s { case .error: return .red; case .warning: return .orange; case .info: return .blue }
    }
}

// MARK: - Notes Tab

struct NotesView: View {
    @Binding var project: Project
    @EnvironmentObject var appState: AppState
    @State private var showAddLink: Bool = false
    @State private var newLinkLabel: String = ""
    @State private var newLinkURL: String = ""
    @State private var newTagInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Label("Notas Pessoais", systemImage: "pencil").font(.headline)
                TextEditor(text: $project.notes)
                    .font(.system(.callout, design: .rounded))
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: project.notes) { _, _ in appState.update(project) }
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Label("Descrição", systemImage: "text.alignleft").font(.headline)
                TextEditor(text: $project.description)
                    .font(.callout)
                    .frame(minHeight: 70)
                    .padding(8)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: project.description) { _, _ in appState.update(project) }
            }

            Divider()

            // Links management
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Links", systemImage: "link").font(.headline)
                    Spacer()
                    Button {
                        newLinkLabel = ""; newLinkURL = ""
                        showAddLink = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Adicionar link")
                }

                if project.links.isEmpty {
                    Text("Sem links. Adiciona URLs úteis ao projecto.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(project.links) { link in
                        HStack(spacing: 8) {
                            Image(systemName: link.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(link.label)
                                    .font(.system(size: 13, weight: .medium))
                                Text(link.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let url = URL(string: link.url) {
                                Link(destination: url) {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .help("Abrir link")
                            }
                            Button {
                                project.links.removeAll { $0.id == link.id }
                                appState.update(project)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .help("Remover link")
                        }
                        .padding(10)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Inline add form
                if showAddLink {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Label (ex: Produção)", text: $newLinkLabel)
                                .textFieldStyle(.roundedBorder)
                            TextField("URL (ex: https://…)", text: $newLinkURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Spacer()
                            Button("Cancelar") { showAddLink = false }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Adicionar") {
                                let icon = iconForURL(newLinkURL)
                                let link = ProjectLink(label: newLinkLabel.isEmpty ? newLinkURL : newLinkLabel,
                                                       url: newLinkURL, icon: icon)
                                project.links.append(link)
                                appState.update(project)
                                showAddLink = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newLinkURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(12)
                    .background(.quinary.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // Tags
            VStack(alignment: .leading, spacing: 10) {
                Label("Tags", systemImage: "tag").font(.headline)
                if project.tags.isEmpty {
                    Text("Sem tags. Adiciona palavras-chave ao projecto.")
                        .font(.callout).foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(project.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                Button {
                                    project.tags.removeAll { $0 == tag }
                                    appState.update(project)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        }
                    }
                }

                // Add tag
                HStack(spacing: 6) {
                    TextField("Nova tag…", text: $newTagInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTag() }
                    Button("Adicionar") { addTag() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addTag() {
        let tag = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !project.tags.contains(tag) else {
            newTagInput = ""; return
        }
        project.tags.append(tag)
        appState.update(project)
        newTagInput = ""
    }

    private func iconForURL(_ url: String) -> String {
        let l = url.lowercased()
        if l.contains("github") { return "chevron.left.forwardslash.chevron.right" }
        if l.contains("figma")  { return "pencil.and.ruler" }
        if l.contains("notion") { return "doc.text" }
        if l.contains("linear") { return "checklist" }
        if l.contains("slack")  { return "message" }
        if l.contains("vercel") || l.contains("netlify") || l.contains("railway") { return "cloud" }
        return "link"
    }
}

// MARK: - Flow Layout (wrapping tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var maxY: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y = maxY + spacing
            }
            origin.x += size.width + spacing
            maxY = max(maxY, origin.y + size.height)
        }
        return CGSize(width: maxWidth, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var maxY: CGFloat = bounds.minY
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y = maxY + spacing
            }
            view.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            maxY = max(maxY, origin.y + size.height)
        }
    }
}
