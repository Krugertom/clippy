import AppKit
import SwiftUI

/// Development aid: `Clippy --snapshot /path/out.png` seeds demo data (use with
/// CLIPPY_DATA_DIR to avoid touching real history), renders the bar, and exits.
@MainActor
enum Snapshot {
    static func seed(_ store: ClipStore) {
        guard store.clips.isEmpty else { return }
        let useful = store.addTag(name: "Useful stuff", colorHex: "#3E8BFF")
        _ = store.addTag(name: "Snippets", colorHex: "#FF9F43")

        func demoImage(width: Int, height: Int, colors: [NSColor]) -> Data {
            let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
                let gradient = NSGradient(colors: colors)
                gradient?.draw(in: rect, angle: 35)
                return true
            }
            let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
            return rep.representation(using: .png, properties: [:])!
        }

        func addImageClip(width: Int, height: Int, colors: [NSColor], app: (String, String), age: TimeInterval, tag: ClipTag? = nil) {
            let id = UUID()
            let name = "\(id.uuidString).png"
            let data = demoImage(width: width, height: height, colors: colors)
            try? data.write(to: store.imagesURL.appendingPathComponent(name))
            var clip = Clip(id: id, kind: .image, imageFile: name, pixelWidth: width, pixelHeight: height,
                            appName: app.0, bundleID: app.1, date: Date().addingTimeInterval(-age),
                            contentHash: "image:\(id)")
            if let tag { clip.tagIDs = [tag.id] }
            store.add(clip)
        }

        func addText(_ text: String, app: (String, String), age: TimeInterval, kind: ClipKind = .text, tag: ClipTag? = nil) {
            var clip = Clip(kind: kind, text: text, appName: app.0, bundleID: app.1,
                            date: Date().addingTimeInterval(-age), contentHash: "text:\(text)".sha256Hash)
            if let tag { clip.tagIDs = [tag.id] }
            store.add(clip)
        }

        let terminal = ("Terminal", "com.apple.Terminal")
        let safari = ("Safari", "com.apple.Safari")
        let finder = ("Finder", "com.apple.finder")
        let notes = ("Notes", "com.apple.Notes")

        addText("test_SjEXzorprPJtkHGauNnw-ITOVBNE", app: terminal, age: 3 * 86_400)
        addText("npx eas-cli@latest env:create \\\n  --environment production \\\n  --name EXPO_PUBLIC_REVENUECAT_IOS_API_KEY \\\n  --value appl_YOUR_REVENUECAT_APPLE_KEY", app: terminal, age: 3 * 86_400)
        addText("npx eas-cli@latest build \\\n  --platform ios \\\n  --profile production \\\n  --auto-submit", app: terminal, age: 3 * 86_400, tag: useful)
        addText("--dangerously-skip-permissions", app: notes, age: 3 * 86_400)
        var files = Clip(kind: .file,
                         filePaths: ["/Users/tomkruger/projects/clippy/build.sh"],
                         appName: finder.0, bundleID: finder.1,
                         date: Date().addingTimeInterval(-2 * 86_400), contentHash: "file:demo")
        files.text = "/Users/tomkruger/projects/clippy/build.sh"
        store.add(files)
        addText("Grazly", app: notes, age: 2 * 86_400)
        addImageClip(width: 320, height: 1400,
                     colors: [NSColor.systemPurple, NSColor.systemIndigo], app: safari, age: 2 * 86_400)
        addText("https://www.airbnb.com/rooms/15953024477", app: safari, age: 17 * 3600, kind: .link, tag: useful)
        addImageClip(width: 1275, height: 815,
                     colors: [NSColor.systemOrange, NSColor.systemRed, NSColor.black], app: safari, age: 30)
    }

    static func capture(panelView: NSView, to path: String) {
        panelView.layoutSubtreeIfNeeded()
        guard let rep = panelView.bitmapImageRepForCachingDisplay(in: panelView.bounds) else { return }
        panelView.cacheDisplay(in: panelView.bounds, to: rep)

        // Composite over a wallpaper-like gradient so legibility can be judged.
        let size = panelView.bounds.size
        let padded = NSImage(size: NSSize(width: size.width + 80, height: size.height + 80), flipped: false) { rect in
            NSGradient(colors: [NSColor(srgbRed: 0.28, green: 0.42, blue: 0.25, alpha: 1),
                                NSColor(srgbRed: 0.45, green: 0.40, blue: 0.28, alpha: 1),
                                NSColor(srgbRed: 0.20, green: 0.28, blue: 0.35, alpha: 1)])?
                .draw(in: rect, angle: 20)
            let image = NSImage(size: size)
            image.addRepresentation(rep)
            image.draw(at: NSPoint(x: 40, y: 40), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        if let tiff = padded.tiffRepresentation,
           let outRep = NSBitmapImageRep(data: tiff),
           let png = outRep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
