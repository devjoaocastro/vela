import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var filter: SidebarFilter = .all
    @Environment(\.openSettings) private var openSettings

    enum SidebarFilter: String, CaseIterable {
        case all     = "Todos"
        case active  = "Activos"
        case issues  = "Issues"
        case ideas   = "Ideias"
    }

    var displayed: [Project] {
        let base = appState.filteredProjects
        switch filter {
        case .all:    return base
        case .active: return base.filter { $0.status == .active || $0.status == .slow }
        case .issues: return base.filter { !$0.issues.isEmpty }
        case .ideas:  return base.filter { $0.status == .idea }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Divider()
            filterControl
            Divider()
            projectList
            Divider()
            bottomBar
        }
    }

    // MARK: - Stats bar

    private var statsBar: some View {
        HStack(spacing: 14) {
            statItem(
                value: appState.projects.count,
                label: "total",
                systemImage: "folder",
                color: .secondary
            )
            statItem(
                value: appState.projects.filter { $0.status == .active }.count,
                label: "activos",
                systemImage: "circle.fill",
                color: .green
            )
            let issues = appState.projects.reduce(0) { $0 + $1.issues.count }
            if issues > 0 {
                statItem(value: issues, label: "issues", systemImage: "exclamationmark.triangle.fill", color: .orange)
            }
            Spacer()
            if appState.isScanning {
                ProgressView().scaleEffect(0.55)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.windowBackground)
    }

    private func statItem(value: Int, label: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Filter

    private var filterControl: some View {
        Picker("", selection: $filter) {
            ForEach(SidebarFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: - List

    private var projectList: some View {
        List(displayed, selection: Binding(
            get: { appState.selectedProject?.id },
            set: { id in appState.selectedProject = appState.projects.first { $0.id == id } }
        )) { project in
            ProjectRowView(project: project)
                .tag(project.id)
                .contextMenu { rowContextMenu(project) }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.windowBackground)
        .overlay {
            if displayed.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text(appState.projects.isEmpty ? "Sem projectos" : "Sem resultados")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 2) {
            Button(action: { appState.showNewProjectSheet = true }) {
                Image(systemName: "plus")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Novo Projecto (⌘N)")

            Spacer()

            Button(action: { Task { await appState.scanProjects() } }) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Actualizar (⌘R)")
            .disabled(appState.isScanning)

            Button(action: { openSettings() }) {
                Image(systemName: "gear")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Configurações (⌘,)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.windowBackground)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func rowContextMenu(_ project: Project) -> some View {
        Button("Abrir no Editor") { appState.openInEditor(project) }
        Button("Mostrar no Finder") { appState.revealInFinder(project) }

        if let remote = project.git.remoteURL {
            let webURL = remote
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
            if let url = URL(string: webURL) {
                Divider()
                Link("Abrir no GitHub", destination: url)
            }
        }

        Divider()
        Button("Arquivar") {
            var p = project
            p.status = .archived
            appState.update(p)
        }
        Button("Ocultar da Lista", role: .destructive) {
            appState.excludeProject(project)
        }
    }
}

// MARK: - Project Row

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 10) {
            // Type icon — stronger fill
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: project.type.color).opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: project.type.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: project.type.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.status.color))
                        .frame(width: 5, height: 5)
                    Text(activityLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if !project.issues.isEmpty {
                let hasCritical = project.issues.contains { $0.severity == .error }
                Text("\(project.issues.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(hasCritical ? Color.red : Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 3)
    }

    private var activityLabel: String {
        guard let days = project.git.daysSinceLastCommit else { return project.type.rawValue }
        switch days {
        case 0:     return "hoje"
        case 1:     return "ontem"
        case 2...6: return "há \(days) dias"
        case 7...29:
            let w = days / 7
            return "há \(w) sem."
        default:
            let m = days / 30
            return "há \(m) mês"
        }
    }
}
