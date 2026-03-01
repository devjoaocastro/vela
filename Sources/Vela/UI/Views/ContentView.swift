import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmEngine: LLMEngine
    @EnvironmentObject var embeddedLLM: EmbeddedLLM

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let project = appState.selectedProject {
                ProjectDetailView(project: Binding(
                    get: { appState.projects.first(where: { $0.id == project.id }) ?? project },
                    set: { appState.update($0) }
                ))
            } else {
                EmptyStateView()
            }
        }
        // Native macOS search — pipes to AppState.searchQuery
        .searchable(text: $appState.searchQuery, placement: .sidebar, prompt: "Procurar projectos…")
        // Native toolbar
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { Task { await appState.scanProjects() } }) {
                    Label("Actualizar", systemImage: "arrow.clockwise")
                }
                .help("Actualizar projectos (⌘R)")
                .disabled(appState.isScanning)

                Button(action: { appState.showNewProjectSheet = true }) {
                    Label("Novo Projecto", systemImage: "plus")
                }
                .help("Novo Projecto (⌘N)")
            }
        }
        .task {
            if appState.projects.isEmpty {
                await appState.scanProjects()
            }
        }
        .sheet(isPresented: $appState.showNewProjectSheet) {
            NewProjectSheet()
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var embeddedLLM: EmbeddedLLM

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sailboat")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            VStack(spacing: 8) {
                Text("Vela")
                    .font(.largeTitle.bold())
                Text("Selecciona um projecto na sidebar\nou faz scan para descobrir os teus projectos.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Group {
                if appState.isScanning {
                    Label("A scannar o Mac…", systemImage: "magnifyingglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Scan Agora") {
                        Task { await appState.scanProjects() }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r", modifiers: .command)
                }
            }

            Spacer()

            // AI status — bottom of empty state
            HStack(spacing: 6) {
                Image(systemName: embeddedLLM.backendIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(embeddedLLM.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if case .checking = embeddedLLM.state {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }
}
