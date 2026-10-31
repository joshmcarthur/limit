import SwiftUI
import WidgetKit

/// The widget bundle builder can't branch on the OS version, so the entry point picks the bundle.
@main
struct LimitWidgetsMain {
    static func main() {
        if #available(iOS 18.0, *) {
            LimitWidgetsBundle.main()
        } else {
            LimitWidgetsBundleBefore18.main()
        }
    }
}

@available(iOS 18.0, *)
struct LimitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DriveLiveActivityWithSmallLayout()
    }
}

struct LimitWidgetsBundleBefore18: WidgetBundle {
    var body: some Widget {
        DriveLiveActivity()
    }
}
