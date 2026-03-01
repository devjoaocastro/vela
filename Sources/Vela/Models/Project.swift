import Foundation

// MARK: - Project Type

enum ProjectType: String, Codable, CaseIterable {
    case swiftApp      = "Swift / SwiftUI"
    case reactNative   = "React Native"
    case nextJS        = "Next.js"
    case node          = "Node.js"
    case python        = "Python"
    case flutter       = "Flutter"
    case rust          = "Rust"
    case staticSite    = "Site Estático"
    case documentation = "Documentação"
    case unknown       = "Desconhecido"

    var icon: String {
        switch self {
        case .swiftApp:      return "swift"
        case .reactNative:   return "iphone"
        case .nextJS:        return "globe"
        case .node:          return "server.rack"
        case .python:        return "terminal"
        case .flutter:       return "iphone.and.ipad"
        case .rust:          return "gear"
        case .staticSite:    return "doc.richtext"
        case .documentation: return "book.closed"
        case .unknown:       return "questionmark.folder"
        }
    }

    var color: String {
        switch self {
        case .swiftApp:      return "#F05138"
        case .reactNative:   return "#61DAFB"
        case .nextJS:        return "#000000"
        case .node:          return "#339933"
        case .python:        return "#3776AB"
        case .flutter:       return "#02569B"
        case .rust:          return "#CE4A00"
        case .staticSite:    return "#E34F26"
        case .documentation: return "#8B5CF6"
        case .unknown:       return "#6B7280"
        }
    }
}

// MARK: - Project Status

enum ProjectStatus: String, Codable, CaseIterable {
    case idea      = "Ideia"
    case active    = "Activo"
    case slow      = "Lento"
    case inactive  = "Inactivo"
    case archived  = "Arquivado"
    case dead      = "Morto"

    var icon: String {
        switch self {
        case .idea:     return "lightbulb"
        case .active:   return "circle.fill"
        case .slow:     return "clock"
        case .inactive: return "moon.zzz"
        case .archived: return "archivebox"
        case .dead:     return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .idea:     return "#F59E0B"
        case .active:   return "#10B981"
        case .slow:     return "#F97316"
        case .inactive: return "#6B7280"
        case .archived: return "#8B5CF6"
        case .dead:     return "#EF4444"
        }
    }
}

// MARK: - Project Issue

struct ProjectIssue: Identifiable {
    let id = UUID()
    let severity: IssueSeverity
    let message: String

    enum IssueSeverity {
        case warning, error, info
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .error:   return "xmark.octagon.fill"
            case .info:    return "info.circle.fill"
            }
        }
    }
}

// MARK: - Git Info

struct GitInfo {
    var hasGit: Bool = false
    var hasRemote: Bool = false
    var remoteURL: String? = nil
    var lastCommitDate: Date? = nil
    var lastCommitMessage: String? = nil
    var uncommittedChanges: Int = 0
    var totalCommits: Int = 0
    var activeBranch: String? = nil

    var daysSinceLastCommit: Int? {
        guard let date = lastCommitDate else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}

// MARK: - Disk Info

struct DiskInfo {
    var totalBytes: Int64 = 0
    var codeBytes: Int64 = 0
    var dependencyBytes: Int64 = 0
    var buildBytes: Int64 = 0

    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }
    var formattedCode: String  { ByteCountFormatter.string(fromByteCount: codeBytes, countStyle: .file) }
    var formattedDeps: String  { ByteCountFormatter.string(fromByteCount: dependencyBytes, countStyle: .file) }
}

// MARK: - Project

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String
    var type: ProjectType
    var status: ProjectStatus
    var description: String
    var notes: String
    var links: [ProjectLink]
    var tags: [String]
    var createdAt: Date
    var scannedAt: Date

    // Non-persisted, computed at scan time
    var git: GitInfo = GitInfo()
    var disk: DiskInfo = DiskInfo()
    var issues: [ProjectIssue] = []
    var languages: [String: Double] = [:]  // lang → % of files
    var markdownFiles: [String] = []       // paths to .md files

    // Vitality score 0-100
    var vitalityScore: Int {
        guard git.hasGit else { return 10 }
        var score = 50
        if let days = git.daysSinceLastCommit {
            switch days {
            case 0...7:   score += 40
            case 8...30:  score += 25
            case 31...90: score += 10
            case 91...180: score -= 10
            default:      score -= 25
            }
        }
        if git.hasRemote { score += 10 }
        if !markdownFiles.isEmpty { score += 5 }
        if git.uncommittedChanges > 0 { score -= 5 }
        return max(0, min(100, score))
    }

    var computedStatus: ProjectStatus {
        guard git.hasGit else {
            return markdownFiles.isEmpty ? .dead : .idea
        }
        guard let days = git.daysSinceLastCommit else { return .inactive }
        switch days {
        case 0...14:  return .active
        case 15...60: return .slow
        case 61...180: return .inactive
        default:      return .dead
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, type, status, description, notes, links, tags, createdAt, scannedAt
    }

    init(id: UUID = UUID(), name: String, path: String, type: ProjectType = .unknown) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.status = .active
        self.description = ""
        self.notes = ""
        self.links = []
        self.tags = []
        self.createdAt = Date()
        self.scannedAt = Date()
    }
}

// MARK: - Project Link

struct ProjectLink: Identifiable, Codable {
    let id: UUID
    var label: String
    var url: String
    var icon: String

    init(id: UUID = UUID(), label: String, url: String, icon: String = "link") {
        self.id = id
        self.label = label
        self.url = url
        self.icon = icon
    }
}
