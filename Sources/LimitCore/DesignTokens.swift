import Foundation

/// An sRGB colour, 0...255 per channel.
public struct HexColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    /// WCAG relative luminance.
    public var luminance: Double {
        func channel(_ value: UInt8) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public func contrast(with other: HexColor) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

public struct ThemedColor: Equatable, Sendable {
    public let light: HexColor
    public let dark: HexColor

    public init(light: UInt32, dark: UInt32) {
        self.light = HexColor(light)
        self.dark = HexColor(dark)
    }

    public init(_ both: UInt32) {
        self.init(light: both, dark: both)
    }
}

/// Colour tokens from the Limit design system (`tokens.json`). The sign colours never change with theme:
/// the sign is a road object, not UI. `signRing` red is reserved for the sign.
public enum DesignTokens {
    public static let ground = ThemedColor(light: 0xF2F2F7, dark: 0x000000)
    public static let surface = ThemedColor(light: 0xFFFFFF, dark: 0x1C1C1E)
    public static let ink = ThemedColor(light: 0x000000, dark: 0xFFFFFF)
    public static let inkMuted = ThemedColor(light: 0x6C6C70, dark: 0xA1A1A6)
    public static let separator = ThemedColor(light: 0xC6C6C8, dark: 0x38383A)
    public static let tint = ThemedColor(light: 0x0A63C9, dark: 0x4DA3FF)
    public static let caution = ThemedColor(0xFF9F0A)
    public static let onCaution = ThemedColor(0x000000)
    public static let cautionInk = ThemedColor(light: 0xA35200, dark: 0xFFB340)
    public static let unknown = ThemedColor(0x8E8E93)
    public static let signFace = ThemedColor(0xFFFFFF)
    public static let signRing = ThemedColor(0xC8102E)
    public static let signInk = ThemedColor(0x111111)
    public static let island = ThemedColor(0x000000)
    public static let onIsland = ThemedColor(0xFFFFFF)

    // Spacing (pt) and radii.
    public static let space1 = 4.0, space2 = 8.0, space3 = 12.0, space4 = 16.0
    public static let space5 = 20.0, space6 = 24.0, space8 = 32.0
    public static let radiusSmall = 8.0, radiusMedium = 12.0, radiusLarge = 22.0
}
