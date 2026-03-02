import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project? = nil
    @Published var isScanning: Bool = false
    @Published var searchQuery: String = ""
    @Published var filterType: ProjectType? = nil
    @Published var filterStatus: ProjectStatus? = nil
    @Published var showNewProjectSheet: Bool = false
    @Published var showCommandPalette: Bool = false
    @Published var lastScanDate: Date? = nil
    @Published var excludedPaths: Set<String> = []

    private let scanner = ProjectScanner()
    private let storageURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Vela")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("projects.json")
        let saved = UserDefaults.standard.stringArray(forKey: "vela.excludedPaths") ?? []
        excludedPaths = Set(saved)
        loadPersisted()
    }

    // MARK: - Filtered Projects

    var filteredProjects: [Project] {
        projects.filter { p in
            let matchesSearch = searchQuery.isEmpty ||
                p.name.localizedCaseInsensitiveContains(searchQuery) ||
                p.description.localizedCaseInsensitiveContains(searchQuery)
            let matchesType = filterType == nil || p.type == filterType
            let matchesStatus = filterStatus == nil || p.status == filterStatus
            return matchesSearch && matchesType && matchesStatus
        }
    }

    var activeProjects: [Project]   { filteredProjects.filter { $0.status == .active } }
    var slowProjects: [Project]     { filteredProjects.filter { $0.status == .slow } }
    var inactiveProjects: [Project] { filteredProjects.filter { $0.status == .inactive || $0.status == .dead } }
    var ideaProjects: [Project]     { filteredProjects.filter { $0.status == .idea } }

    // MARK: - Scan

    func scanProjects() async {
        isScanning = true
        let found = await scanner.scanAll()

        // Merge: preserve user notes/links from existing projects
        var merged: [Project] = []
        for var scanned in found {
            if let existing = projects.first(where: { $0.path == scanned.path }) {
                scanned.notes = existing.notes
                scanned.links = existing.links
                scanned.tags = existing.tags
                scanned.description = existing.description.isEmpty ? scanned.description : existing.description
            }
            merged.append(scanned)
        }

        projects = merged.filter { !excludedPaths.contains($0.path) }
        lastScanDate = Date()
        isScanning = false
        persist()
    }

    // MARK: - Exclude

    func excludeProject(_ project: Project) {
        excludedPaths.insert(project.path)
        UserDefaults.standard.set(Array(excludedPaths), forKey: "vela.excludedPaths")
        projects.removeAll { $0.path == project.path }
        if selectedProject?.path == project.path {
            selectedProject = projects.first
        }
    }

    func restoreAllExcluded() {
        excludedPaths.removeAll()
        UserDefaults.standard.removeObject(forKey: "vela.excludedPaths")
        Task { await scanProjects() }
    }

    // MARK: - Update

    func update(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
            persist()
        }
    }

    // MARK: - Persistence

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(projects) {
            try? data.write(to: storageURL)
        }
    }

    private func loadPersisted() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? decoder.decode([Project].self, from: data) else { return }
        projects = saved
    }

    // MARK: - Open in Editor

    func openInEditor(_ project: Project) {
        let url = URL(fileURLWithPath: project.path)
        // Ordered by preference — uses bundle ID so path doesn't matter
        let bundleIDs = [
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",  // Cursor
            "dev.zed.zed",                      // Zed
            "com.sublimetext.4",
            "com.sublimetext.3",
            "com.apple.dt.Xcode"
        ]
        let config = NSWorkspace.OpenConfiguration()
        config.promptsUserIfNeeded = false
        for bid in bundleIDs {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                        configuration: config, completionHandler: nil)
                return
            }
        }
        // Fallback: default app for the folder
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ project: Project) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
    }
}
