import Foundation

actor ProjectScanner {

    // Directories to always skip
    private let skipDirs: Set<String> = [
        "node_modules", ".git", ".build", "build", "dist", ".next",
        "DerivedData", ".cache", "__pycache__", ".tox", "venv", ".venv",
        "Library", "Applications", "Music", "Movies", "Pictures",
        ".Trash", "Volumes"
    ]

    // Root directories to scan
    private let scanRoots: [String] = [
        "~/Desktop/Projetos",
        "~/Projects",
        "~/Developer",
        "~/Documents/Projects",
        "~/CascadeProjects",
        "~"
    ]

    // Max depth from scan root (prevents deep traversal into node_modules etc)
    private let maxDepth = 3

    // MARK: - Public

    func scanAll() async -> [Project] {
        var projects: [Project] = []
        var seen: Set<String> = []

        for root in scanRoots {
            let expanded = (root as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            let found = await scanDirectory(URL(fileURLWithPath: expanded), depth: 0)
            for p in found {
                if !seen.contains(p.path) {
                    seen.insert(p.path)
                    projects.append(p)
                }
            }
        }

        return projects.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Directory Scan

    private func scanDirectory(_ url: URL, depth: Int) async -> [Project] {
        guard depth <= maxDepth else { return [] }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // Check if THIS directory IS a project
        if depth > 0, let project = await detectProject(at: url) {
            return [project]
        }

        // Otherwise recurse into subdirectories
        var results: [Project] = []
        for item in contents {
            let name = item.lastPathComponent
            guard skipDirs.contains(name) == false else { continue }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            if isDir.boolValue {
                let found = await scanDirectory(item, depth: depth + 1)
                results.append(contentsOf: found)
            }
        }
        return results
    }

    // MARK: - Project Detection

    private func detectProject(at url: URL) async -> Project? {
        let fm = FileManager.default
        let path = url.path
        let name = url.lastPathComponent

        // Skip hidden directories
        guard !name.hasPrefix(".") else { return nil }

        // Skip generic non-project directories
        let skipNames: Set<String> = ["node_modules", "venv", ".venv", "__pycache__", "DerivedData"]
        guard !skipNames.contains(name) else { return nil }

        func has(_ file: String) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent(file).path)
        }

        func hasDir(_ dir: String) -> Bool {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.appendingPathComponent(dir).path, isDirectory: &isDir)
            return isDir.boolValue
        }

        // Detect type based on signature files
        let type: ProjectType
        if has("Package.swift") {
            type = .swiftApp
        } else if has("pubspec.yaml") {
            type = .flutter
        } else if has("Cargo.toml") {
            type = .rust
        } else if has("package.json") {
            let pkgData = try? Data(contentsOf: url.appendingPathComponent("package.json"))
            let pkgStr = pkgData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if pkgStr.contains("react-native") || pkgStr.contains("expo") {
                type = .reactNative
            } else if pkgStr.contains("next") {
                type = .nextJS
            } else {
                type = .node
            }
        } else if has("requirements.txt") || has("pyproject.toml") || has("setup.py") {
            type = .python
        } else if has("index.html") && !has("package.json") {
            type = .staticSite
        } else {
            // Check if there are only .md/.pdf files (documentation/idea)
            let contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
            let codeFiles = contents.filter { f in
                let ext = (f as NSString).pathExtension.lowercased()
                return ["swift", "py", "js", "ts", "rs", "go", "dart"].contains(ext)
            }
            if codeFiles.isEmpty && !contents.isEmpty {
                let hasMarkdown = contents.contains { ($0 as NSString).pathExtension.lowercased() == "md" }
                if hasMarkdown {
                    type = .documentation
                } else {
                    return nil  // Not a recognisable project
                }
            } else if codeFiles.isEmpty {
                return nil
            } else {
                type = .unknown
            }
        }

        var project = Project(name: name, path: path, type: type)
        project = await enrichWithGit(project, at: url)
        project = await enrichWithDisk(project, at: url)
        project = await enrichWithIssues(project, at: url)
        project = enrichWithMarkdown(project, at: url)
        project.status = project.computedStatus
        return project
    }

    // MARK: - Git Enrichment

    private func enrichWithGit(_ project: Project, at url: URL) async -> Project {
        var p = project
        let gitPath = url.appendingPathComponent(".git").path
        guard FileManager.default.fileExists(atPath: gitPath) else { return p }

        p.git.hasGit = true

        // Last commit date + message
        if let output = shell("git -C \(url.path.quoted) log -1 --format=%ci|||%s 2>/dev/null") {
            let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|||")
            if parts.count == 2 {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withTimeZone]
                p.git.lastCommitDate = formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces))
                p.git.lastCommitMessage = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        // Total commits
        if let out = shell("git -C \(url.path.quoted) rev-list --count HEAD 2>/dev/null") {
            p.git.totalCommits = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        // Active branch
        if let out = shell("git -C \(url.path.quoted) branch --show-current 2>/dev/null") {
            p.git.activeBranch = out.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remote
        if let out = shell("git -C \(url.path.quoted) remote get-url origin 2>/dev/null") {
            let remote = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remote.isEmpty {
                p.git.hasRemote = true
                p.git.remoteURL = remote
            }
        }

        // Uncommitted changes
        if let out = shell("git -C \(url.path.quoted) status --porcelain 2>/dev/null") {
            p.git.uncommittedChanges = out.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        }

        return p
    }

    // MARK: - Disk Enrichment

    private func enrichWithDisk(_ project: Project, at url: URL) async -> Project {
        var p = project
        var disk = DiskInfo()

        let depDirs = ["node_modules", ".build", "build", "dist", ".next", "DerivedData", "venv", ".venv"]

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                // Check if we're inside a dependency dir
                let components = fileURL.pathComponents
                let isDep = depDirs.contains { dep in components.contains(dep) }
                let isBuild = ["build", "dist", ".next", "DerivedData"].contains { components.contains($0) }

                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    let bytes = Int64(size)
                    disk.totalBytes += bytes
                    if isDep {
                        disk.dependencyBytes += bytes
                    } else if isBuild {
                        disk.buildBytes += bytes
                    } else {
                        disk.codeBytes += bytes
                    }
                }
            }
        }

        p.disk = disk
        return p
    }

    // MARK: - Issues Detection

    private func enrichWithIssues(_ project: Project, at url: URL) async -> Project {
        var p = project
        var issues: [ProjectIssue] = []
        let fm = FileManager.default

        func has(_ file: String) -> Bool { fm.fileExists(atPath: url.appendingPathComponent(file).path) }

        // No .gitignore
        if p.git.hasGit && !has(".gitignore") {
            issues.append(ProjectIssue(severity: .warning, message: "Sem .gitignore"))
        }

        // .env exposed
        if has(".env") {
            let gitignore = (try? String(contentsOf: url.appendingPathComponent(".gitignore"))) ?? ""
            if !gitignore.contains(".env") {
                issues.append(ProjectIssue(severity: .error, message: ".env não está no .gitignore"))
            }
        }

        // No README
        if !has("README.md") && !has("readme.md") {
            issues.append(ProjectIssue(severity: .info, message: "Sem README.md"))
        }

        // No remote
        if p.git.hasGit && !p.git.hasRemote {
            issues.append(ProjectIssue(severity: .info, message: "Sem repositório remoto (GitHub)"))
        }

        // Uncommitted changes
        if p.git.uncommittedChanges > 0 {
            issues.append(ProjectIssue(severity: .warning,
                message: "\(p.git.uncommittedChanges) ficheiro(s) por commitar"))
        }

        // Heavy node_modules
        if p.disk.dependencyBytes > 500_000_000 {
            let size = ByteCountFormatter.string(fromByteCount: p.disk.dependencyBytes, countStyle: .file)
            issues.append(ProjectIssue(severity: .info,
                message: "node_modules pesa \(size) — podes apagar e reinstalar"))
        }

        p.issues = issues
        return p
    }

    // MARK: - Markdown Files

    private func enrichWithMarkdown(_ project: Project, at url: URL) -> Project {
        var p = project
        var mds: [String] = []

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "md" {
                    mds.append(fileURL.path)
                }
            }
        }
        p.markdownFiles = mds
        return p
    }

    // MARK: - Shell Helper

    private func shell(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

private extension String {
    var quoted: String { "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'" }
}
