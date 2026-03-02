import SwiftUI

// MARK: - ⌘K Command Palette

struct CommandPaletteView: View {
    @EnvironmentObject var appState: AppState
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    private var results: [Project] {
        let all = appState.projects.sorted {
            // Recent activity first
            ($0.git.lastCommitDate ?? Date.distantPast) > ($1.git.lastCommitDate ?? Date.distantPast)
        }
        guard !query.isEmpty else { return Array(all.prefix(12)) }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.type.rawValue.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { close() }

            // Palette panel
            VStack(spacing: 0) {
                searchBar
                Divider()
                resultsList
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .frame(width: 540)
            .frame(maxHeight: 480)
        }
        .onAppear { searchFocused = true }
        .onKeyPress(.upArrow)   { move(-1) }
        .onKeyPress(.downArrow) { move(+1) }
        .onKeyPress(.return)    { confirm() }
        .onKeyPress(.escape)    { close(); return .handled }
        .onChange(of: query)    { _, _ in selectedIndex = 0 }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Ir para projecto…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .onSubmit { _ = confirm() }

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘K")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text("Sem resultados para \"\(query)\"")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, project in
                            PaletteRow(project: project, isSelected: idx == selectedIndex)
                                .id(idx)
                                .onTapGesture { navigate(to: project) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedIndex) { _, idx in
                    withAnimation { proxy.scrollTo(idx, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func move(_ delta: Int) -> KeyPress.Result {
        let count = results.count
        guard count > 0 else { return .handled }
        selectedIndex = (selectedIndex + delta + count) % count
        return .handled
    }

    @discardableResult
    private func confirm() -> KeyPress.Result {
        guard selectedIndex < results.count else { return .handled }
        navigate(to: results[selectedIndex])
        return .handled
    }

    private func navigate(to project: Project) {
        appState.selectedProject = project
        close()
    }

    private func close() {
        appState.showCommandPalette = false
    }
}

// MARK: - Palette Row

struct PaletteRow: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: project.type.color).opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: project.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: project.type.color))
            }

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(project.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Status + type
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.status.color))
                        .frame(width: 5, height: 5)
                    Text(project.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(project.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
        .contentShape(Rectangle())
    }
}
