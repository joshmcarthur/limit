import ActivityKit
import SwiftUI
import WidgetKit
import LimitCore

/// Lock Screen and Dynamic Island presentation while a drive is active: sign leading, speed trailing,
/// everywhere. No alerts from the activity.
struct DriveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            LockScreenView(snapshot: Self.snapshot(context))
                .activityBackgroundTint(Palette.surface)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            let snapshot = Self.snapshot(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SpeedSignView(state: snapshot.sign, diameter: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SpeedReadoutView(speed: snapshot.speed, over: snapshot.over, size: 44, unitFont: .caption)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(snapshot.roadName ?? "Speed limit")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(Palette.onIsland)
                }
            } compactLeading: {
                SpeedSignView(state: snapshot.sign, diameter: 24)
            } compactTrailing: {
                CompactSpeed(speed: snapshot.speed, over: snapshot.over)
            } minimal: {
                SpeedSignView(state: snapshot.sign, diameter: 24)
            }
        }
    }

    /// Updates are best-effort and may be throttled. Once the system marks the content stale, show the
    /// unknown state rather than a frozen number.
    private static func snapshot(_ context: ActivityViewContext<DriveActivityAttributes>) -> DriveSnapshot {
        context.isStale ? .searching : context.state.snapshot
    }
}

private struct LockScreenView: View {
    let snapshot: DriveSnapshot

    var body: some View {
        HStack(spacing: DesignTokens.space4) {
            SpeedSignView(state: snapshot.sign, diameter: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.roadName ?? "Speed limit")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(Palette.ink)
                Text("Limit from NZTA register")
                    .font(.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
            SpeedReadoutView(speed: snapshot.speed, over: snapshot.over, size: 44, unitFont: .caption)
        }
        .padding(DesignTokens.space4)
    }
}

/// Compact trailing region. Over the limit it gains an arrow as well as the caution colour.
private struct CompactSpeed: View {
    let speed: Int?
    let over: OverLimitState

    var body: some View {
        HStack(spacing: 2) {
            if over.isOver { Image(systemName: "arrow.up").font(.caption.bold()).accessibilityHidden(true) }
            Text(speed.map(String.init) ?? "–")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(over.isOver ? Palette.cautionInk : Palette.onIsland)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabels.readout(speed: speed, over: over))
    }
}
