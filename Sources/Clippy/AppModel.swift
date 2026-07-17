import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    let store: ClipStore
    var monitor: ClipboardMonitor!
    weak var panelController: PanelController?

    @Published var searchText = ""
    @Published var searchActive = false
    @Published var selectedTagID: UUID?
    @Published var selectedIndex = 0
    @Published var showSettings = false
    @Published var showTagCreator = false
    @Published var copiedClipID: UUID?
    @Published var multiSelection: [UUID] = []   // ordered by selection
    @Published var multiFlash = false
    /// Mirrors the system appearance. Injected into SwiftUI explicitly because
    /// NSGlassEffectView's content view doesn't propagate colorScheme reliably.
    @Published var isDarkMode = true

    private var cancellables: Set<AnyCancellable> = []

    init() {
        store = ClipStore()
        monitor = ClipboardMonitor(store: store)
        // Only re-render while the bar is visible; background captures shouldn't
        // cost any UI work. panelWillShow() publishes on open, so the view
        // catches up with everything captured while hidden.
        store.objectWillChange.sink { [weak self] _ in
            guard let self, self.panelController?.isVisible ?? true else { return }
            self.objectWillChange.send()
        }.store(in: &cancellables)
    }

    var filteredClips: [Clip] {
        var result = store.clips
        if let tagID = selectedTagID {
            result = result.filter { $0.tagIDs.contains(tagID) }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { clip in
                if let text = clip.text, text.localizedCaseInsensitiveContains(query) { return true }
                if let app = clip.appName, app.localizedCaseInsensitiveContains(query) { return true }
                if clip.kind.title.localizedCaseInsensitiveContains(query) { return true }
                if let paths = clip.filePaths, paths.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
                return false
            }
        }
        return result
    }

    // MARK: - Actions

    func copyToPasteboard(_ clip: Clip) {
        // A copy→hide→paste cycle is already in flight (e.g. double-click) — don't start a second.
        guard copiedClipID == nil, !multiFlash else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clip.kind {
        case .text, .link:
            pb.setString(clip.text ?? "", forType: .string)
        case .image:
            if let file = clip.imageFile,
               let data = try? Data(contentsOf: store.imagesURL.appendingPathComponent(file)) {
                pb.setData(data, forType: .png)
            }
        case .file:
            let urls = (clip.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
        }
        copiedClipID = clip.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.copiedClipID = nil
            self?.panelController?.hide()
            self?.pasteAfterHide()
        }
    }

    // MARK: - Appearance override

    enum AppearanceMode: String, CaseIterable {
        case system, light, dark

        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appearanceMode")
            Self.applyAppearance(newValue)
        }
    }

    /// Sets the app-wide appearance; the effectiveAppearance KVO then updates
    /// isDarkMode and every dynamic color follows.
    static func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Paste into whichever app has focus. The panel is non-activating, so the
    /// user's app never lost focus — a short delay lets the panel finish closing.
    var pasteOnClick: Bool {
        get { UserDefaults.standard.object(forKey: "pasteOnClick") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pasteOnClick") }
    }

    private func pasteAfterHide() {
        guard pasteOnClick else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Paster.pasteToFrontmostApp()
        }
    }

    func toggleMultiSelect(_ clip: Clip) {
        if let idx = multiSelection.firstIndex(of: clip.id) {
            multiSelection.remove(at: idx)
        } else {
            multiSelection.append(clip.id)
        }
    }

    /// Combines every multi-selected clip into a single pasteboard write.
    /// Memory-safe: image payloads are size-checked before loading, read one at a
    /// time inside autoreleasepool, memory-mapped, and capped at 150 MB total.
    func copyMultiSelection() {
        guard !multiFlash, copiedClipID == nil else { return }
        let selected = multiSelection.compactMap { id in store.clips.first(where: { $0.id == id }) }
        guard !selected.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()

        if selected.allSatisfy({ $0.kind == .file }) {
            // All files → one multi-file paste (Finder pastes them all at once).
            let urls = selected.flatMap { $0.filePaths ?? [] }.map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
        } else if selected.allSatisfy({ $0.kind == .image }) {
            // All images → one pasteboard item per image, within a hard byte budget.
            let maxTotalBytes = 150 * 1024 * 1024
            var budget = maxTotalBytes
            var items: [NSPasteboardItem] = []
            for clip in selected {
                autoreleasepool {
                    guard let file = clip.imageFile else { return }
                    let url = store.imagesURL.appendingPathComponent(file)
                    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
                    guard let size, size <= budget else { return }
                    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
                    let item = NSPasteboardItem()
                    item.setData(data, forType: .png)
                    items.append(item)
                    budget -= size
                }
            }
            pb.writeObjects(items)
        } else {
            // Mixed / textual → join text, links and file paths in selection order.
            let parts = selected.compactMap { clip -> String? in
                switch clip.kind {
                case .text, .link: return clip.text
                case .file: return clip.filePaths?.joined(separator: "\n")
                case .image: return nil
                }
            }
            pb.setString(parts.joined(separator: "\n"), forType: .string)
        }

        multiFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.multiFlash = false
            self?.multiSelection = []
            self?.panelController?.hide()
            self?.pasteAfterHide()
        }
    }

    // MARK: - Drag out

    private static let dragNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f
    }()

    static let dragTempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClippyDrag", isDirectory: true)

    /// Item provider for dragging a card into another app. If the card is part
    /// of a multi-selection, the drag carries the combined content.
    func dragProvider(for clip: Clip) -> NSItemProvider {
        if multiSelection.count > 1, multiSelection.contains(clip.id) {
            let clips = multiSelection.compactMap { id in store.clips.first(where: { $0.id == id }) }
            let parts = clips.compactMap { c -> String? in
                switch c.kind {
                case .text, .link: return c.text
                case .file: return c.filePaths?.joined(separator: "\n")
                case .image: return nil
                }
            }
            if !parts.isEmpty {
                return NSItemProvider(object: parts.joined(separator: "\n") as NSString)
            }
            // All-image selections fall through and drag the grabbed card's image.
        }
        switch clip.kind {
        case .text:
            return NSItemProvider(object: (clip.text ?? "") as NSString)
        case .link:
            if let url = URL(string: clip.text ?? "") {
                let provider = NSItemProvider(object: url as NSURL)
                provider.registerObject((clip.text ?? "") as NSString, visibility: .all)
                return provider
            }
            return NSItemProvider(object: (clip.text ?? "") as NSString)
        case .image:
            guard let file = clip.imageFile else { return NSItemProvider() }
            let source = store.imagesURL.appendingPathComponent(file)
            // Clone to a nicely named temp file so drops into Finder look good.
            // APFS clones are instant — no real copy happens.
            try? FileManager.default.createDirectory(at: Self.dragTempDir, withIntermediateDirectories: true)
            let dest = Self.dragTempDir
                .appendingPathComponent("Image \(Self.dragNameFormatter.string(from: clip.date)).png")
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: source, to: dest)
            }
            // Register both representations: file URL (Finder, Slack, Mail…)
            // and raw PNG (image wells, editors). Data is loaded lazily on drop.
            let provider = NSItemProvider()
            provider.suggestedName = dest.lastPathComponent
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                                visibility: .all) { completion in
                completion(dest.dataRepresentation, nil)
                return nil
            }
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier,
                                                visibility: .all) { completion in
                let data = try? Data(contentsOf: source, options: .mappedIfSafe)
                completion(data, data == nil ? CocoaError(.fileReadNoSuchFile) : nil)
                return nil
            }
            return provider
        case .file:
            guard let path = clip.filePaths?.first else { return NSItemProvider() }
            return NSItemProvider(contentsOf: URL(fileURLWithPath: path)) ?? NSItemProvider()
        }
    }

    func handleEscape() {
        if showSettings { showSettings = false; return }
        if showTagCreator { showTagCreator = false; return }
        if !multiSelection.isEmpty { multiSelection = []; return }
        if searchActive || !searchText.isEmpty {
            searchText = ""
            searchActive = false
            return
        }
        panelController?.hide()
    }

    func moveSelection(by delta: Int) {
        let count = filteredClips.count
        guard count > 0 else { return }
        selectedIndex = min(max(0, selectedIndex + delta), count - 1)
    }

    func deleteSelected() {
        let clips = filteredClips
        guard clips.indices.contains(selectedIndex) else { return }
        store.delete(clips[selectedIndex])
        selectedIndex = min(selectedIndex, max(0, filteredClips.count - 1))
    }

    func copySelected() {
        if !multiSelection.isEmpty {
            copyMultiSelection()
            return
        }
        let clips = filteredClips
        guard clips.indices.contains(selectedIndex) else { return }
        copyToPasteboard(clips[selectedIndex])
    }

    /// ⌘X — copy to clipboard, then remove from history (tags and all).
    func cutSelected() {
        if !multiSelection.isEmpty {
            let selected = multiSelection.compactMap { id in store.clips.first(where: { $0.id == id }) }
            monitor.suppressNextChange()
            copyMultiSelection()
            for clip in selected { store.delete(clip) }
            return
        }
        let clips = filteredClips
        guard clips.indices.contains(selectedIndex) else { return }
        let clip = clips[selectedIndex]
        monitor.suppressNextChange()
        copyToPasteboard(clip)
        store.delete(clip)
        selectedIndex = min(selectedIndex, max(0, filteredClips.count - 1))
    }

    func panelWillShow() {
        objectWillChange.send()   // pick up clips captured while hidden
        selectedIndex = 0
        showSettings = false
        showTagCreator = false
        multiSelection = []
    }
}
