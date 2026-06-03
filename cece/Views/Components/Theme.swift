import SwiftUI

extension Color {
    /// Creates a color from a hex string such as "#3cb89a" or "3cb89a".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Central design tokens for the ce·ce app.
enum Theme {
    enum Palette {
        static let background = Color(.systemGroupedBackground)   // #f2f2f7
        /// Card / grouped-row surface that sits on top of `background`.
        static let surface = Color(.secondarySystemGroupedBackground)
        static let teal = Color(hex: "#3cb89a")
        static let blue = Color(hex: "#4a7fd4")
        static let textPrimary = Color(hex: "#1c1c1e")
        static let textSecondary = Color(hex: "#8e8e93")
        static let border = Color(hex: "#c8c8cc")
        static let separator = Color(hex: "#e5e5ea")
        /// Destructive actions (delete, foul) — system red for platform familiarity.
        static let destructive = Color.red
        /// Error / validation messages.
        static let error = Color.red
    }

    /// Status colours for tournament bracket nodes (and related badges).
    enum Status {
        static let waiting = Palette.textSecondary
        static let ready = Palette.teal
        static let inProgress = Palette.blue
        static let completed = Palette.textPrimary
        static let champion = Palette.teal
    }

    /// Corner-radius scale, used across cards, buttons and tiles.
    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    /// Standard snooker ball colors keyed by their point value.
    enum Ball {
        static let red = Color(hex: "#d63b3b")
        static let yellow = Color(hex: "#e8b800")
        static let green = Color(hex: "#2a7d32")
        static let brown = Color(hex: "#b86e18")
        static let blue = Palette.blue   // same #4a7fd4, kept in one place
        static let pink = Color(hex: "#e060a0")
        static let black = Color(hex: "#1c1c1e")

        /// Returns the color for a ball worth `points`.
        static func color(forPoints points: Int) -> Color {
            switch points {
            case 1: return red
            case 2: return yellow
            case 3: return green
            case 4: return brown
            case 5: return blue
            case 6: return pink
            case 7: return black
            default: return .gray
            }
        }
    }
}
