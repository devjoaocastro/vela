import SwiftUI
import AppKit

// MARK: - App Delegate (menu bar + lifecycle)

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep alive in menu bar instead of quitting
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sailboat.fill", accessibilityDescription: "Vela")
            button.image?.isTemplate = true
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }

    @objc private func toggleWindow() {
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - App Entry

@main
struct VelaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState    = AppState()
    @StateObject private var llmEngine   = LLMEngine()
    @StateObject private var embeddedLLM = EmbeddedLLM()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(llmEngine)
                .environmentObject(embeddedLLM)
                .frame(minWidth: 980, minHeight: 620)
                .onAppear {
                    // Re-detect embedded model availability on appear
                    Task { await embeddedLLM.detect() }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Novo Projecto…") { appState.showNewProjectSheet = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Actualizar Projectos") {
                    Task { await appState.scanProjects() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        // Settings window — ⌘,
        Settings {
            SettingsView()
                .environmentObject(llmEngine)
                .environmentObject(embeddedLLM)
        }
    }
}
