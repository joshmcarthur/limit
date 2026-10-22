import SwiftUI
import LimitCore

/// How fresh the speed limit data is, in an inset grouped list. Title says the state; subtitle says
/// when and from where. Only the stale state surfaces on driving screens, as the sign badge.
struct SyncStatusRow: View {
    let state: SyncState
    var retry: () -> Void = {}

    var body: some View {
        let row = FreshnessText.row(for: state, now: Date())
        HStack(alignment: .top, spacing: DesignTokens.space3) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.headline)
                Text(row.subtitle).font(.footnote).foregroundStyle(Palette.inkMuted)
                if case .updating(let progress) = state {
                    if let progress {
                        ProgressView(value: progress).tint(Palette.tint).padding(.top, 6)
                    } else {
                        ProgressView().progressViewStyle(.linear).tint(Palette.tint).padding(.top, 6)
                    }
                }
            }
            Spacer(minLength: 0)
            if showsRetry {
                Button("Retry", action: retry).buttonStyle(.borderless).foregroundStyle(Palette.tint)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var showsRetry: Bool {
        switch state {
        case .failed, .stale, .neverSynced: return true
        case .updating, .upToDate: return false
        }
    }

    private var symbol: String {
        switch state {
        case .upToDate: return "checkmark.circle"
        case .updating: return "arrow.triangle.2.circlepath"
        case .stale, .failed: return "exclamationmark.triangle"
        case .neverSynced: return "arrow.down.circle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .upToDate, .neverSynced: return Palette.inkMuted
        case .updating: return Palette.tint
        case .stale, .failed: return Palette.cautionInk
        }
    }
}

extension SyncState {
    /// Symbol and colour for the one-line footer on the driving screen.
    var footerSymbol: String {
        switch self {
        case .upToDate: return "checkmark.circle"
        case .updating: return "arrow.triangle.2.circlepath"
        case .stale, .failed, .neverSynced: return "exclamationmark.triangle"
        }
    }

    var footerColor: Color {
        switch self {
        case .stale, .failed, .neverSynced: return Palette.cautionInk
        case .upToDate, .updating: return Palette.inkMuted
        }
    }
}
