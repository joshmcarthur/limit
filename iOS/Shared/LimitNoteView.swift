import SwiftUI
import LimitCore

/// Says that the limit above is a seasonal or temporary one. Quiet, but not colour alone: it's text.
struct LimitNoteView: View {
    let note: LimitNote

    var body: some View {
        Label(note.label, systemImage: "calendar.badge.clock")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, DesignTokens.space3)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.separator))
            .multilineTextAlignment(.center)
    }
}
