import AppKit
import SwiftUI

/// Borderless, non-activating panel that can still become key (so search typing works
/// without stealing focus from the frontmost app).
final class ClippyPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onArrow: ((Int) -> Void)?
    var onReturn: (() -> Void)?
    var onType: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onCopyKey: (() -> Void)?
    var onCutKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        let editingText = firstResponder is NSTextView
        switch event.keyCode {
        case 123 where !editingText: onArrow?(-1)   // left
        case 124 where !editingText: onArrow?(1)    // right
        case 36 where !editingText: onReturn?()     // return
        case 53: onEscape?()                        // esc (safety net)
        case 51 where !editingText && event.modifierFlags.contains(.command):
            onDelete?()                             // ⌘⌫ deletes selected clip
        case 8 where !editingText && event.modifierFlags.contains(.command):
            onCopyKey?()                            // ⌘C copies selected (like ↩)
        case 7 where !editingText && event.modifierFlags.contains(.command):
            onCutKey?()                             // ⌘X copies + deletes
        default:
            if !editingText,
               let chars = event.characters, !chars.isEmpty,
               let scalar = chars.unicodeScalars.first,
               !CharacterSet.controlCharacters.contains(scalar),
               event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                onType?(chars)                      // type anywhere to search
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

@MainActor
final class PanelController {
    private let panel: ClippyPanel
    private let model: AppModel
    private(set) var isVisible = false
    private var clickOutsideMonitor: Any?
    private var appearanceObservation: NSKeyValueObservation?

    private static let barHeight: CGFloat = 300
    private static let margin: CGFloat = 10

    init(model: AppModel) {
        self.model = model
        panel = ClippyPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // No window shadow: it traces the square window frame and shows up as a
        // ghost border around the glass's rounded corners.
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // No pinned appearance: glass + content follow the system light/dark mode.

        let glass = NSGlassEffectView()
        glass.cornerRadius = 30
        glass.style = .regular
        let hosting = NSHostingView(rootView: BarView().environmentObject(model))
        // Never let SwiftUI content size drive the window — oversized overlays
        // must clip inside the bar, not grow the panel off-screen.
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 30
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        glass.contentView = hosting
        panel.contentView = glass
        self.hostingView = hosting

        model.isDarkMode = NSApp.effectiveAppearance.isDark
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak model] app, _ in
            Task { @MainActor in model?.isDarkMode = app.effectiveAppearance.isDark }
        }

        panel.onEscape = { [weak model] in model?.handleEscape() }
        panel.onArrow = { [weak model] delta in model?.moveSelection(by: delta) }
        panel.onReturn = { [weak model] in model?.copySelected() }
        if !CommandLine.arguments.contains("--snapshot") {
            panel.onType = { [weak model] chars in
                model?.searchActive = true
                model?.searchText += chars
            }
        }
        panel.onDelete = { [weak model] in model?.deleteSelected() }
        panel.onCopyKey = { [weak model] in model?.copySelected() }
        panel.onCutKey = { [weak model] in model?.cutSelected() }
        model.panelController = self
    }

    private(set) var hostingView: NSView?
    var snapshotView: NSView? { hostingView }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let screen else { return }
        let vf = screen.visibleFrame
        let width = vf.width - Self.margin * 2
        let frame = NSRect(x: vf.minX + Self.margin,
                           y: vf.minY + Self.margin,
                           width: width,
                           height: Self.barHeight)
        model.panelWillShow()
        installClickOutsideMonitor()
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        var slide = frame
        slide.origin.y -= 24
        panel.setFrame(slide, display: false)
        if CommandLine.arguments.contains("--snapshot") {
            panel.orderFrontRegardless()   // don't steal keystrokes during dev captures
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
        isVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        removeClickOutsideMonitor()
        var slide = panel.frame
        slide.origin.y -= 20
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(slide, display: true)
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    /// Dismiss when the user clicks anywhere outside the bar (other apps, desktop, menu bar).
    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.hide()
                }
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
