import AppKit
import CryptoKit

enum ClipKind: String, Codable, CaseIterable {
    case text
    case link
    case image
    case file

    var title: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    /// Header tint, matching the reference design's colored card headers.
    var headerColor: NSColor {
        switch self {
        case .text: return NSColor(srgbRed: 0.42, green: 0.43, blue: 0.46, alpha: 1)
        case .link: return NSColor(srgbRed: 0.10, green: 0.16, blue: 0.36, alpha: 1)
        case .image: return NSColor(srgbRed: 0.16, green: 0.38, blue: 0.94, alpha: 1)
        case .file: return NSColor(srgbRed: 0.08, green: 0.12, blue: 0.25, alpha: 1)
        }
    }
}

struct ClipTag: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
}

struct Clip: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: ClipKind
    var text: String?          // text content, link URL string
    var filePaths: [String]?   // for kind == .file
    var imageFile: String?     // original image file name inside images/
    var thumbFile: String?     // downscaled preview inside thumbs/
    var pixelWidth: Int?
    var pixelHeight: Int?
    var appName: String?
    var bundleID: String?
    var date: Date = Date()
    var tagIDs: [UUID] = []
    var contentHash: String

    var charCount: Int { text?.count ?? 0 }

    static func == (lhs: Clip, rhs: Clip) -> Bool { lhs.id == rhs.id && lhs.date == rhs.date && lhs.tagIDs == rhs.tagIDs }
}

extension String {
    var sha256Hash: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
