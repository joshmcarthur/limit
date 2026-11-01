import SwiftUI
import UIKit
import LimitCore

extension UIColor {
    convenience init(_ hex: HexColor) {
        self.init(red: CGFloat(hex.red) / 255, green: CGFloat(hex.green) / 255, blue: CGFloat(hex.blue) / 255, alpha: 1)
    }
}

extension Color {
    /// Resolves to the light or dark value of a design token with the system appearance.
    init(_ token: ThemedColor) {
        if token.light == token.dark {
            self.init(uiColor: UIColor(token.light))
        } else {
            self.init(uiColor: UIColor { traits in
                UIColor(traits.userInterfaceStyle == .dark ? token.dark : token.light)
            })
        }
    }

    /// One solid token colour for a known appearance.
    /// The Lock Screen card tint and its text can otherwise resolve against different trait collections,
    /// which draws the dark-mode ink (white) on the light card.
    init(_ token: ThemedColor, scheme: ColorScheme) {
        let hex: HexColor
        switch scheme {
        case .dark:
            hex = token.dark
        case .light:
            hex = token.light
        @unknown default:
            hex = token.light
        }
        self.init(uiColor: UIColor(hex))
    }
}

/// The Limit design system colours. `signRing` is reserved for the speed sign.
enum Palette {
    static let ground = Color(DesignTokens.ground)
    static let surface = Color(DesignTokens.surface)
    static let ink = Color(DesignTokens.ink)
    static let inkMuted = Color(DesignTokens.inkMuted)
    static let separator = Color(DesignTokens.separator)
    static let tint = Color(DesignTokens.tint)
    static let caution = Color(DesignTokens.caution)
    static let onCaution = Color(DesignTokens.onCaution)
    static let cautionInk = Color(DesignTokens.cautionInk)
    static let unknown = Color(DesignTokens.unknown)
    static let signFace = Color(DesignTokens.signFace)
    static let signRing = Color(DesignTokens.signRing)
    static let signInk = Color(DesignTokens.signInk)
    static let island = Color(DesignTokens.island)
    static let onIsland = Color(DesignTokens.onIsland)
}
