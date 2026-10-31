import SwiftUI
import LimitCore

struct OnboardingFlow: View {
    private enum Step { case welcome, location, ready }
    @State private var step = Step.welcome

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcomeView { go(.location) }
                    .background(Palette.surface.ignoresSafeArea())
            case .location:
                OnboardingLocationView { go(.ready) }
                    .background(Palette.surface.ignoresSafeArea())
            case .ready:
                OnboardingReadyView()
                    .background(Palette.ground.ignoresSafeArea())
            }
        }
        .transition(.opacity)
    }

    private func go(_ next: Step) {
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }
}
