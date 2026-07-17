import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject var model: AppModel
    let clip: Clip
    let isSelected: Bool

    @State private var hovering = false

    private var multiSelectionOrder: Int? {
        model.multiSelection.firstIndex(of: clip.id).map { $0 + 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBody)
            footer
        }
        .frame(width: Theme.cardWidth, height: Theme.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1)
        )
        .overlay(alignment: .topLeading) { multiSelectBadge }
        .overlay(copiedOverlay)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
        .scaleEffect(hovering ? 1.025 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
        .contextMenu { contextMenuItems }
    }

    private var borderColor: Color {
        if multiSelectionOrder != nil { return Theme.accent }
        if isSelected { return Theme.accent }
        if hovering { return .primary.opacity(0.35) }
        return .primary.opacity(0.12)
    }

    @ViewBuilder
    private var multiSelectBadge: some View {
        if let order = multiSelectionOrder {
            Text("\(order)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.accent))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5))
                .offset(x: -6, y: -6)
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(clip.kind.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text(Theme.relativeTime(clip.date))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 4)
            if !clip.tagIDs.isEmpty {
                HStack(spacing: 3) {
                    ForEach(taggedColors, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 7, height: 7)
                    }
                }
            }
            if let icon = AppIconCache.shared.icon(forBundleID: clip.bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .help(clip.appName ?? "")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(
            LinearGradient(colors: [Color(nsColor: clip.kind.headerColor).opacity(0.96),
                                    Color(nsColor: clip.kind.headerColor).opacity(0.82)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var taggedColors: [String] {
        clip.tagIDs.compactMap { id in model.store.tags.first(where: { $0.id == id })?.colorHex }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch clip.kind {
        case .text:
            Text(textPreview)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textPrimary.opacity(0.95))
                .lineLimit(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(clip.text ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.95))
                    .lineLimit(5)
                if let host = URL(string: clip.text ?? "")?.host {
                    Text(host)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
        case .image:
            ThumbView(clip: clip)
        case .file:
            FileContentView(clip: clip)
        }
    }

    private var textPreview: String {
        let text = clip.text ?? ""
        return text.count > 600 ? String(text.prefix(600)) : text
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            Text(footerText)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Theme.cardBody)
    }

    private var footerText: String {
        switch clip.kind {
        case .text, .link:
            let count = clip.charCount
            let formatted = Theme.numberFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
            return "\(formatted) character\(count == 1 ? "" : "s")"
        case .image:
            if let w = clip.pixelWidth, let h = clip.pixelHeight { return "\(w) × \(h)" }
            return "Image"
        case .file:
            let count = clip.filePaths?.count ?? 0
            return "\(count) file\(count == 1 ? "" : "s")"
        }
    }

    // MARK: - Overlays & menu

    @ViewBuilder
    private var copiedOverlay: some View {
        if model.copiedClipID == clip.id || (model.multiFlash && multiSelectionOrder != nil) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                    Text("Copied")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            model.copyToPasteboard(clip)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Divider()
        if model.store.tags.isEmpty {
            Button {
                model.showTagCreator = true
            } label: {
                Label("New Tag…", systemImage: "plus")
            }
        } else {
            ForEach(model.store.tags) { tag in
                Button {
                    model.store.toggleTag(tag, on: clip)
                } label: {
                    if clip.tagIDs.contains(tag.id) {
                        Label("Remove from \"\(tag.name)\"", systemImage: "checkmark.circle.fill")
                    } else {
                        Label("Save to \"\(tag.name)\"", systemImage: "circle")
                    }
                }
            }
            Button {
                model.showTagCreator = true
            } label: {
                Label("New Tag…", systemImage: "plus")
            }
        }
        Divider()
        Button(role: .destructive) {
            model.store.delete(clip)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Image thumbnail

/// Fixed-frame, aspect-fill thumbnail — odd aspect ratios never distort the card.
private struct ThumbView: View {
    @EnvironmentObject var model: AppModel
    let clip: Clip
    @State private var image: NSImage?

    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200   // bound thumbnail memory for huge histories
        return cache
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.tone.opacity(0.12)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .task(id: clip.id) { await load() }
    }

    private func load() async {
        let key = clip.id.uuidString as NSString
        if let hit = Self.cache.object(forKey: key) {
            image = hit
            return
        }
        guard let file = clip.thumbFile ?? clip.imageFile else { return }
        let url = (clip.thumbFile != nil ? model.store.thumbsURL : model.store.imagesURL)
            .appendingPathComponent(file)
        let loaded = await Task.detached(priority: .userInitiated) { NSImage(contentsOf: url) }.value
        if let loaded {
            Self.cache.setObject(loaded, forKey: key)
            image = loaded
        }
    }
}

// MARK: - File preview

private struct FileContentView: View {
    let clip: Clip

    // NSWorkspace icon lookups hit the disk — cache per path.
    private static let iconCache = NSCache<NSString, NSImage>()

    private func icon(for path: String) -> NSImage {
        if let hit = Self.iconCache.object(forKey: path as NSString) { return hit }
        let icon = NSWorkspace.shared.icon(forFile: path)
        Self.iconCache.setObject(icon, forKey: path as NSString)
        return icon
    }

    var body: some View {
        VStack(spacing: 6) {
            if let path = clip.filePaths?.first {
                Image(nsImage: icon(for: path))
                    .resizable()
                    .frame(width: 44, height: 44)
                Text((path as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text((path as NSString).deletingLastPathComponent)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.head)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
