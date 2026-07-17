import AppKit
import Combine

/// Persists clips + tags as JSON in ~/Library/Application Support/Clippy,
/// with image payloads stored as files alongside.
@MainActor
final class ClipStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published private(set) var tags: [ClipTag] = []

    static let defaultRetention: TimeInterval = 7 * 24 * 3600

    let rootURL: URL
    let imagesURL: URL
    let thumbsURL: URL
    private let storeURL: URL
    private var saveWorkItem: DispatchWorkItem?
    private var pruneTimer: Timer?

    /// Retention window in seconds for untagged clips. 0 = forever.
    var retention: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: "retention") == nil { return Self.defaultRetention }
            return UserDefaults.standard.double(forKey: "retention")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "retention")
            prune()
        }
    }

    var maxItems: Int {
        get { max(50, UserDefaults.standard.object(forKey: "maxItems") as? Int ?? 500) }
        set { UserDefaults.standard.set(newValue, forKey: "maxItems"); prune() }
    }

    init() {
        if let override = ProcessInfo.processInfo.environment["CLIPPY_DATA_DIR"] {
            rootURL = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            rootURL = appSupport.appendingPathComponent("Clippy", isDirectory: true)
        }
        imagesURL = rootURL.appendingPathComponent("images", isDirectory: true)
        thumbsURL = rootURL.appendingPathComponent("thumbs", isDirectory: true)
        storeURL = rootURL.appendingPathComponent("store.json")
        for url in [rootURL, imagesURL, thumbsURL] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        load()
        prune()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.prune() }
        }
    }

    // MARK: - Mutations

    /// Adds a clip; if identical content already exists, bumps it to the front (tags preserved).
    func add(_ clip: Clip) {
        if let idx = clips.firstIndex(where: { $0.contentHash == clip.contentHash }) {
            var existing = clips.remove(at: idx)
            existing.date = clip.date
            // Newest copy wins for source-app attribution.
            existing.appName = clip.appName ?? existing.appName
            existing.bundleID = clip.bundleID ?? existing.bundleID
            clips.insert(existing, at: 0)
            // The fresh clip may have written duplicate image files; discard them.
            if clip.id != existing.id { removePayloadFiles(of: clip) }
        } else {
            clips.insert(clip, at: 0)
        }
        prune()
        scheduleSave()
    }

    func delete(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        removePayloadFiles(of: clip)
        scheduleSave()
    }

    func toggleTag(_ tag: ClipTag, on clip: Clip) {
        guard let idx = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        if let t = clips[idx].tagIDs.firstIndex(of: tag.id) {
            clips[idx].tagIDs.remove(at: t)
        } else {
            clips[idx].tagIDs.append(tag.id)
        }
        scheduleSave()
    }

    func addTag(name: String, colorHex: String) -> ClipTag {
        let tag = ClipTag(name: name, colorHex: colorHex)
        tags.append(tag)
        scheduleSave()
        return tag
    }

    func deleteTag(_ tag: ClipTag) {
        tags.removeAll { $0.id == tag.id }
        for i in clips.indices { clips[i].tagIDs.removeAll { $0 == tag.id } }
        scheduleSave()
    }

    /// Wipes untagged history. Tagged clips survive — that's the "saved clipboard".
    func clearHistory() {
        let doomed = clips.filter { $0.tagIDs.isEmpty }
        clips.removeAll { $0.tagIDs.isEmpty }
        for clip in doomed { removePayloadFiles(of: clip) }
        scheduleSave()
    }

    func prune() {
        var doomed: [Clip] = []
        if retention > 0 {
            let cutoff = Date().addingTimeInterval(-retention)
            doomed += clips.filter { $0.tagIDs.isEmpty && $0.date < cutoff }
        }
        let doomedSoFar = Set(doomed.map(\.id))
        let untagged = clips.filter { $0.tagIDs.isEmpty && !doomedSoFar.contains($0.id) }
        if untagged.count > maxItems {
            doomed += untagged.suffix(untagged.count - maxItems)
        }
        guard !doomed.isEmpty else { return }
        let doomedIDs = Set(doomed.map(\.id))
        clips.removeAll { doomedIDs.contains($0.id) }
        for clip in doomed { removePayloadFiles(of: clip) }
        scheduleSave()
    }

    // MARK: - Persistence

    private struct StoreFile: Codable {
        var clips: [Clip]
        var tags: [ClipTag]
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let file = try? JSONDecoder().decode(StoreFile.self, from: data) else { return }
        clips = file.clips.sorted { $0.date > $1.date }
        tags = file.tags
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = StoreFile(clips: clips, tags: tags)
        let url = storeURL
        let item = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func removePayloadFiles(of clip: Clip) {
        if let f = clip.imageFile { try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(f)) }
        if let f = clip.thumbFile { try? FileManager.default.removeItem(at: thumbsURL.appendingPathComponent(f)) }
    }
}
