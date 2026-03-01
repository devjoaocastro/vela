import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM
    @State private var selectedTab: DetailTab = .xray

    enum DetailTab: String, CaseIterable {
        case xray     = "Raio-X"
        case wiki     = "Wiki"
        case security = "Segurança"
        case browser  = "Browser"
        case ai       = "AI"
        case notes    = "Notas"
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
        if selectedTab == .browser {
            let githubURL = project.git.remoteURL?
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
                ?? "https://www.google.com"
            BrowserPanel(initialURL: githubURL)
        } else {
            ScrollView {
                switch selectedTab {
                case .xray:     XRayView(project: project)
                case .wiki:     WikiView(project: project)
                case .security: SecurityView(project: project)
                case .ai:       AIView(project: project)
                case .notes:    NotesView(project: $project)
                case .browser:  EmptyView()
                }
            }
        }
    }

    private func tabIcon(_ tab: DetailTab) -> String {
        switch tab {
        case .xray:     return "waveform.path.ecg"
        case .wiki:     return "book.closed"
        case .security: return "lock.shield"
        case .browser:  return "globe"
        case .ai:       return "sparkles"
        case .notes:    return "pencil"
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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: project.status.color))
                            .frame(width: 6, height: 6)
                        Text(project.status.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: project.status.color))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: project.status.color).opacity(0.12))
                    .clipShape(Capsule())
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

// MARK: - Raio-X Tab

struct XRayView: View {
    let project: Project

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            XRayCard(title: "Git", icon: "arrow.triangle.branch") {
                if project.git.hasGit {
                    XRayRow(label: "Último commit", value: project.git.lastCommitDate.map { formatRelative($0) } ?? "—")
                    XRayRow(label: "Mensagem", value: project.git.lastCommitMessage ?? "—")
                    XRayRow(label: "Total commits", value: "\(project.git.totalCommits)")
                    XRayRow(label: "Branch", value: project.git.activeBranch ?? "—")
                    XRayRow(label: "Remote", value: project.git.hasRemote ? "✓ GitHub" : "✗ Sem remote")
                    if project.git.uncommittedChanges > 0 {
                        XRayRow(label: "Por commitar", value: "\(project.git.uncommittedChanges) ficheiros", valueColor: .orange)
                    }
                } else {
                    Text("Sem repositório Git").foregroundStyle(.secondary).font(.caption)
                }
            }

            XRayCard(title: "Disco", icon: "internaldrive") {
                XRayRow(label: "Total", value: project.disk.formattedTotal)
                XRayRow(label: "Código", value: project.disk.formattedCode, valueColor: .green)
                if project.disk.dependencyBytes > 0 {
                    XRayRow(label: "Dependências", value: project.disk.formattedDeps, valueColor: .orange)
                }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        let total = max(project.disk.totalBytes, 1)
                        let codeRatio = CGFloat(project.disk.codeBytes) / CGFloat(total)
                        let depRatio  = CGFloat(project.disk.dependencyBytes) / CGFloat(total)
                        if codeRatio > 0 {
                            RoundedRectangle(cornerRadius: 3).fill(.green).frame(width: geo.size.width * codeRatio)
                        }
                        if depRatio > 0 {
                            RoundedRectangle(cornerRadius: 3).fill(.orange).frame(width: geo.size.width * depRatio)
                        }
                    }.frame(height: 6)
                }
                .frame(height: 6)
                .padding(.top, 4)
            }

            XRayCard(title: "Vitalidade", icon: "waveform.path.ecg") {
                VStack(spacing: 8) {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: CGFloat(project.vitalityScore) / 100)
                            .stroke(vitalityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(project.vitalityScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(vitalityColor)
                    }
                    .frame(width: 80, height: 80)
                    Text(vitalityLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(vitalityColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            XRayCard(title: "Stack", icon: "square.stack.3d.up") {
                XRayRow(label: "Tipo", value: project.type.rawValue)
                XRayRow(label: "Path", value: URL(fileURLWithPath: project.path).lastPathComponent)
                if !project.markdownFiles.isEmpty {
                    XRayRow(label: "Docs .md", value: "\(project.markdownFiles.count) ficheiro(s)")
                }
                XRayRow(label: "Problemas", value: "\(project.issues.count)",
                        valueColor: project.issues.isEmpty ? .secondary : .orange)
            }
        }
        .padding(20)
    }

    private var vitalityColor: Color {
        switch project.vitalityScore {
        case 70...: return .green
        case 40...69: return .orange
        default:    return .red
        }
    }
    private var vitalityLabel: String {
        switch project.vitalityScore {
        case 70...: return "Vivo e activo"
        case 40...69: return "Adormecido"
        default:    return "Precisa de atenção"
        }
    }
    private func formatRelative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "pt_PT")
        return f.localizedString(for: date, relativeTo: Date())
    }
}

struct XRayCard<Content: View>: View {
    let title: String; let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct XRayRow: View {
    let label: String; let value: String
    var valueColor: Color = .primary
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(valueColor).lineLimit(1).truncationMode(.middle)
        }
    }
}

// MARK: - Wiki Tab

struct WikiView: View {
    let project: Project
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Sobre o Projecto", systemImage: "info.circle").font(.headline)
                Text(project.description.isEmpty ? "Sem descrição. Adiciona na tab Notas." : project.description)
                    .foregroundStyle(project.description.isEmpty ? .secondary : .primary)
            }
            Divider()
            if !project.markdownFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Documentos", systemImage: "doc.text").font(.headline)
                    ForEach(project.markdownFiles, id: \.self) { path in MarkdownFileRow(path: path) }
                }
                Divider()
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Links", systemImage: "link").font(.headline)
                if project.links.isEmpty {
                    Text("Sem links.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(project.links) { link in
                        HStack {
                            Image(systemName: link.icon).foregroundStyle(.secondary)
                            Text(link.label)
                            Spacer()
                            if let url = URL(string: link.url) {
                                Link(link.url, destination: url).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if project.git.hasGit, let msg = project.git.lastCommitMessage {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Onde Ficou", systemImage: "clock.arrow.circlepath").font(.headline)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chevron.right.2").foregroundStyle(.secondary).font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg).font(.system(.callout, design: .monospaced))
                            if let date = project.git.lastCommitDate {
                                Text(date.formatted(date: .long, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkdownFileRow: View {
    let path: String
    var body: some View {
        Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill").foregroundStyle(.purple).font(.system(size: 12))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notas Pessoais", systemImage: "pencil").font(.headline)
            TextEditor(text: $project.notes)
                .font(.system(.callout, design: .rounded))
                .frame(minHeight: 200)
                .padding(8)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: project.notes) { _, _ in appState.update(project) }
            Divider()
            Label("Descrição", systemImage: "text.alignleft").font(.headline)
            TextEditor(text: $project.description)
                .font(.callout)
                .frame(minHeight: 80)
                .padding(8)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: project.description) { _, _ in appState.update(project) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
