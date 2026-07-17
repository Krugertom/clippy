import SwiftUI

enum Theme {
    static let cardWidth: CGFloat = 232
    static let cardHeight: CGFloat = 206
    static let cardCorner: CGFloat = 14
    /// Card/overlay surfaces adapt to the system appearance.
    static let cardBody = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor.black.withAlphaComponent(0.58)
                          : NSColor.white.withAlphaComponent(0.72)
    })
    static let overlayBody = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor.black.withAlphaComponent(0.68)
                          : NSColor.white.withAlphaComponent(0.80)
    })
    static let accent = Color(red: 0.25, green: 0.52, blue: 1.0)

    /// Explicit text colors keyed off the live system appearance. Semantic
    /// styles (.primary/.secondary) resolve through the glass view's vibrancy
    /// and render unpredictably — explicit RGB always renders faithfully.
    static var isDark: Bool { NSApp.effectiveAppearance.isDark }
    static var textPrimary: Color { isDark ? .white : Color(red: 0.10, green: 0.10, blue: 0.12) }
    static var textSecondary: Color { isDark ? Color.white.opacity(0.62) : Color.black.opacity(0.55) }
    /// Neutral fill/stroke tone for chips, hovers and field backgrounds.
    static var tone: Color { isDark ? .white : .black }

    /// Selected chip pill: frosted white in light mode, soft white glaze in dark.
    static var chipSelectedFill: Color { isDark ? Color.white.opacity(0.26) : Color.white.opacity(0.92) }
    static var chipSelectedStroke: Color { isDark ? Color.white.opacity(0.30) : Color.black.opacity(0.08) }

    static let tagPalette: [String] = [
        "#FF6B6B", "#FF9F43", "#FECA57", "#2ECC71",
        "#00CEC9", "#3E8BFF", "#A55EEA", "#FD79A8",
    ]

    // Formatters are expensive to create — build once, reuse everywhere.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "now" }
        return relativeFormatter.localizedString(for: date, relativeTo: now)
    }
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

/// Soft rounded hover highlight for icons, chips and tags.
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    var shape: AnyShape = AnyShape(Capsule())

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Theme.tone.opacity(hovering ? 0.13 : 0)))
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
            }
    }
}

extension View {
    func hoverHighlight(_ shape: some Shape = Capsule()) -> some View {
        modifier(HoverHighlight(shape: AnyShape(shape)))
    }
}
