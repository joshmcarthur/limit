import ActivityKit
import SwiftUI
import WidgetKit
import LimitCore

/// Lock Screen and Dynamic Island presentation while a drive is active: sign leading, speed trailing,
/// everywhere. No alerts from the activity.
struct DriveLiveActivity: Widget {
    var body: some WidgetConfiguration { Self.configuration }

    fileprivate static var configuration: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            ActivityBody(snapshot: Self.snapshot(context), receivedAt: context.state.sentAt)
                .activityBackgroundTint(Palette.surface)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            let snapshot = Self.snapshot(context)
            let receivedAt = context.state.sentAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SpeedSignView(state: snapshot.sign, diameter: 56, note: snapshot.limitNote)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SpeedReadoutView(speed: snapshot.speed, over: snapshot.over, size: 44, unitFont: .caption, receivedAt: receivedAt)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(snapshot.roadName ?? "Speed limit")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(Palette.onIsland)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let note = snapshot.limitNote {
                        Text(note.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.onIsland)
                    }
                }
            } compactLeading: {
                SpeedSignView(state: snapshot.sign, diameter: 24, note: snapshot.limitNote)
            } compactTrailing: {
                CompactSpeed(speed: snapshot.speed, over: snapshot.over, receivedAt: receivedAt)
            } minimal: {
                SpeedSignView(state: snapshot.sign, diameter: 24, note: snapshot.limitNote)
            }
        }
    }

    private static func snapshot(_ context: ActivityViewContext<DriveActivityAttributes>) -> DriveSnapshot {
        context.state.snapshot
    }
}

/// The same activity for iOS 18 and later, which can say it has a small layout. The system uses that on
/// surfaces too small for the Lock Screen card: the Apple Watch Smart Stack, and CarPlay where it shows
/// Live Activities. The bundle picks this or `DriveLiveActivity` by OS version.
@available(iOS 18.0, *)
struct DriveLiveActivityWithSmallLayout: Widget {
    var body: some WidgetConfiguration {
        DriveLiveActivity.configuration.supplementalActivityFamilies([.small])
    }
}

/// The Lock Screen card, or the small layout where the system asks for it.
private struct ActivityBody: View {
    let snapshot: DriveSnapshot
    let receivedAt: Date

    var body: some View {
        if #available(iOS 18.0, *) {
            FamilyBody(snapshot: snapshot, receivedAt: receivedAt)
        } else {
            LockScreenView(snapshot: snapshot, receivedAt: receivedAt)
        }
    }
}

@available(iOS 18.0, *)
private struct FamilyBody: View {
    let snapshot: DriveSnapshot
    let receivedAt: Date
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: SmallView(snapshot: snapshot, receivedAt: receivedAt)
        default: LockScreenView(snapshot: snapshot, receivedAt: receivedAt)
        }
    }
}

/// Sign and speed with its unit, nothing else: the room is small and the driver is moving.
private struct SmallView: View {
    let snapshot: DriveSnapshot
    let receivedAt: Date

    var body: some View {
        HStack(spacing: DesignTokens.space3) {
            SpeedSignView(state: snapshot.sign, diameter: 44, note: snapshot.limitNote)
            Spacer(minLength: 0)
            SpeedReadoutView(speed: snapshot.speed, over: snapshot.over, size: 32, unitFont: .caption2, receivedAt: receivedAt)
        }
        .padding(DesignTokens.space3)
    }
}

private struct LockScreenView: View {
    let snapshot: DriveSnapshot
    let receivedAt: Date

    var body: some View {
        HStack(spacing: DesignTokens.space4) {
            SpeedSignView(state: snapshot.sign, diameter: 56, note: snapshot.limitNote)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.roadName ?? "Speed limit")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(Palette.ink)
                if let note = snapshot.limitNote {
                    // Room is tight, so the note takes the attribution line's place while it's showing.
                    Text(note.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                } else {
                    Text(LimitCore.attribution)
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            Spacer(minLength: 0)
            SpeedReadoutView(speed: snapshot.speed, over: snapshot.over, size: 44, unitFont: .caption, receivedAt: receivedAt)
        }
        .padding(DesignTokens.space4)
    }
}

/// Compact trailing region. Over the limit it gains an arrow as well as the caution colour.
private struct CompactSpeed: View {
    let speed: Int?
    let over: OverLimitState
    var receivedAt: Date?

    var body: some View {
        HStack(spacing: 2) {
            if over.isOver { Image(systemName: "arrow.up").font(.caption.bold()).accessibilityHidden(true) }
            // The unit goes under the number: CarPlay appears to show this compact view, and a bare number
            // doesn't say whether it's km/h or mph. Pulled in from the edge, where the Island's corner clips it.
            VStack(spacing: 0) {
                let font = Font.system(size: 17, weight: .heavy, design: .rounded)
                if let receivedAt, let speed, !over.isOver {
                    DimmingText(text: String(speed), font: font, color: Palette.onIsland, receivedAt: receivedAt)
                } else {
                    Text(speed.map(String.init) ?? "–").font(font).monospacedDigit()
                }
                if speed != nil {
                    Text("km/h").font(.system(size: 8, weight: .semibold)).minimumScaleFactor(0.8)
                }
            }
            .padding(.trailing, 5)
            .padding(.bottom, 1)
        }
        .foregroundStyle(over.isOver ? Palette.cautionInk : Palette.onIsland)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabels.readout(speed: speed, over: over))
    }
}
