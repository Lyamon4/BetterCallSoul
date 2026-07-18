import SwiftUI

enum BCSColor {
    static let canvas = Color(red: 247 / 255, green: 246 / 255, blue: 241 / 255)
    static let surface = Color.white
    static let ink = Color(red: 47 / 255, green: 52 / 255, blue: 55 / 255)
    static let secondary = Color(red: 120 / 255, green: 119 / 255, blue: 116 / 255)
    static let divider = Color(red: 231 / 255, green: 229 / 255, blue: 223 / 255)
    static let yellow = Color(red: 242 / 255, green: 212 / 255, blue: 75 / 255)
    static let paleYellow = Color(red: 251 / 255, green: 243 / 255, blue: 219 / 255)
    static let paleGreen = Color(red: 237 / 255, green: 243 / 255, blue: 236 / 255)
    static let greenText = Color(red: 52 / 255, green: 101 / 255, blue: 56 / 255)
}

enum BCSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum BCSMotion {
    static func entryOffset(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : 8
    }

    static func spring(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.38, dampingFraction: 0.86)
    }
}

extension Font {
    static func bcsEditorial(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func bcsBody(_ size: CGFloat = 17, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bcsMeta(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
