# Vela

Native macOS developer dashboard that scans, analyzes, and monitors all your coding projects.

![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-007AFF)
![Dependencies](https://img.shields.io/badge/Dependencies-0-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

Vela automatically discovers every project on your Mac, gives each a health score, runs AI-powered analysis, detects security issues, and shows git stats — all from a single menu bar app.

**Built in 37 minutes. 3,928 lines of Swift. Zero external dependencies.**

## Features

**Project Discovery** — Automatically scans your Mac for coding projects. Detects 10 project types: Swift, React Native, Next.js, Node.js, Python, Flutter, Rust, Static Sites, Documentation, and more.

**Vitality Score** — Every project gets a 0–100 health score based on git activity, remote presence, documentation quality, and uncommitted changes. Projects are classified as Active, Slow, Inactive, or Dead.

**X-Ray Dashboard** — Per-project overview with git info (last commit, total commits, branch, remote), disk usage breakdown (code vs dependencies vs build artifacts), and stack detection.

**AI Analysis** — Ask AI about any project. Get structured verdicts (CONTINUA / ARQUIVA / REFACTORA / LANÇA) with summary, strengths, weaknesses, and next steps. Supports 5 providers:
- Apple Intelligence (on-device, zero cost)
- Ollama (local, free)
- Claude (Anthropic)
- OpenAI
- Google Gemini

**Security Scanning** — Detects exposed secrets (API keys, private keys, database URLs), tracked `.env` files, missing `.gitignore`, and other security issues across all projects.

**README Generation** — One-click AI-generated README for any project, based on its actual structure, stack, and purpose.

**Project Chat** — Conversational AI interface with context about the specific project. Ask questions, get suggestions, understand old codebases.

**Embedded Browser** — Built-in WebKit browser per project that auto-opens the GitHub remote URL.

**Menu Bar App** — Lives in the macOS menu bar (sailboat icon). Always accessible, stays alive when the window is closed.

**Open in Editor** — One-click to open any project in VS Code, Cursor, Xcode, or Finder.

## Architecture

```
Sources/Vela/
├── VelaApp.swift              App entry, menu bar, window management
├── AppState.swift             State management, persistence, editor launching
├── Core/
│   ├── ProjectScanner.swift   Filesystem scanner, git enrichment, disk analysis
│   ├── LLMEngine.swift        Multi-provider LLM client + Keychain storage
│   ├── EmbeddedLLM.swift      Apple Intelligence + Ollama auto-detection
│   └── SecurityScanner.swift  Secret detection, git hygiene checks
├── Models/
│   └── Project.swift          Data models, vitality scoring, issue types
└── UI/
    ├── DesignSystem.swift      Color utilities
    └── Views/
        ├── ContentView.swift        NavigationSplitView layout
        ├── SidebarView.swift        Project list with search and filters
        ├── ProjectDetailView.swift  Header + 6-tab detail view
        ├── AIView.swift             AI analysis, chat, README generation
        ├── SecurityView.swift       Security findings dashboard
        ├── BrowserView.swift        Embedded WebKit browser
        ├── SettingsView.swift       LLM provider configuration
        └── NewProjectSheet.swift    Project creation wizard
```

## Requirements

- macOS 14 (Sonoma) or later
- For Apple Intelligence: macOS 26.0+ with compatible hardware
- For cloud AI: API keys for Claude, OpenAI, or Gemini (stored in macOS Keychain)

## Build & Install

```bash
# Build
make build

# Build + Open
make run

# Release build + Install to /Applications
make install
```

Or with Swift directly:

```bash
swift build -c release
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Build | Swift Package Manager |
| Storage | JSON (~/Library/Application Support/Vela/) |
| Security | macOS Keychain (Security.framework) |
| Browser | WebKit (WKWebView) |
| AI | FoundationModels + HTTP (Ollama, Claude, OpenAI, Gemini) |

**Zero external dependencies.** Pure Apple frameworks only.

## License

MIT — see [LICENSE](LICENSE) for details.

---

Built by [João Castro](https://joaocastro.online) — solo developer from Portugal.
