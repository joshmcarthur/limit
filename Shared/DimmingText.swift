import SwiftUI
import LimitCore

/// Text that dims by itself a set time after it was received, with no update from the app.
///
/// A Live Activity can't run a timeline or change a view at a given moment, but it does keep a
/// `ProgressView(timerInterval:)` moving on its own. Full-strength text is masked by such a bar, which is
/// full until just before `LiveActivityRefresh.dimAfter` and empty from then on, so the text shows at full
/// strength first and then only through the bar's faint track. A dimmed copy underneath keeps it readable.
struct DimmingText: View {
    let text: String
    let font: Font
    let color: Color
    /// When the text was received.
    let receivedAt: Date

    var body: some View {
        Text(text).font(font).monospacedDigit().foregroundStyle(color.opacity(dimmedOpacity))
            .overlay {
                Text(text).font(font).monospacedDigit().foregroundStyle(color)
                    .mask {
                        GeometryReader { geo in
                            ProgressView(timerInterval: window, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                                .progressViewStyle(.linear)
                                .scaleEffect(x: 1, y: max(geo.size.height / 4, 1), anchor: .center)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
            }
    }

    private let dimmedOpacity = 0.4

    /// Brief, so the change reads as a step rather than a sweep.
    private var window: ClosedRange<Date> {
        let end = receivedAt.addingTimeInterval(LiveActivityRefresh.dimAfter)
        return end.addingTimeInterval(-0.25)...end
    }
}
