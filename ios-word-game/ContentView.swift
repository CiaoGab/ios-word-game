import SwiftUI

enum AppScreen {
    case start
    case game
    case milestones
}

struct ContentView: View {
    @StateObject private var milestoneTracker = MilestoneTracker()
    @State private var screen: AppScreen = .start

    var body: some View {
        switch screen {
        case .start:
            StartScreen(
                milestoneTracker: milestoneTracker,
                onPlay: { screen = .game },
                onMilestones: { screen = .milestones }
            )
        case .game:
            GameScreen(
                milestoneTracker: milestoneTracker,
                onQuitToMenu: { screen = .start }
            )
        case .milestones:
            MilestonesScreen(
                milestoneTracker: milestoneTracker,
                onBack: { screen = .start }
            )
        }
    }
}

#Preview {
    ContentView()
}
