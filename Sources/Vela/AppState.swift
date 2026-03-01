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
    @Published var lastScanDate: Date? = nil

    private let scanner = ProjectScanner()
    private let storageURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Vela")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("projects.json")
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

        projects = merged
        lastScanDate = Date()
        isScanning = false
        persist()
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
        let path = project.path
        // Try VSCode first, then Cursor, then Xcode (for Swift), then Finder
        let editors: [(String, [String])] = [
            ("/usr/local/bin/code", ["--new-window", path]),
            ("/usr/bin/env", ["open", "-a", "Cursor", path]),
            ("/usr/bin/open", ["-a", "Xcode", path]),
            ("/usr/bin/open", [path])
        ]
        for (exec, args) in editors {
            if FileManager.default.fileExists(atPath: exec) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: exec)
                process.arguments = args
                try? process.run()
                return
            }
        }
        // Fallback: open in Finder
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func revealInFinder(_ project: Project) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
    }
}
