import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var panelController: PanelController!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let savedMode = AppModel.AppearanceMode(
            rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .system
        AppModel.applyAppearance(savedMode)
        if CommandLine.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        try? FileManager.default.removeItem(at: AppModel.dragTempDir)
        model = AppModel()
        panelController = PanelController(model: model)

        // First run from /Applications: enable start-at-login (toggle in settings).
        if Bundle.main.bundlePath.hasPrefix("/Applications"),
           !UserDefaults.standard.bool(forKey: "didAutoRegisterLogin") {
            UserDefaults.standard.set(true, forKey: "didAutoRegisterLogin")
            try? SMAppService.mainApp.register()
        }

        HotKeyCenter.shared.register { [weak self] in
            self?.panelController.toggle()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clippy")
        }
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show Clippy", action: #selector(togglePanel), keyEquivalent: "1")
        showItem.keyEquivalentModifierMask = [.command]
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu

        if let idx = CommandLine.arguments.firstIndex(of: "--snapshot"),
           CommandLine.arguments.count > idx + 1 {
            let path = CommandLine.arguments[idx + 1]
            Snapshot.seed(model.store)
            panelController.show()
            if CommandLine.arguments.contains("--settings") { model.showSettings = true }
            if CommandLine.arguments.contains("--multiselect") {
                model.multiSelection = model.store.clips.prefix(3).map(\.id)
            }
            if CommandLine.arguments.contains("--tagcreator") { model.showTagCreator = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if let view = self?.panelController.snapshotView {
                    Snapshot.capture(panelView: view, to: path)
                }
                NSApp.terminate(nil)
            }
        }

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.panelController.show()
            }
        }
    }

    @objc func togglePanel() {
        panelController.toggle()
    }
}

let delegate = MainActor.assumeIsolated { AppDelegate() }
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.delegate = delegate
    app.run()
}
