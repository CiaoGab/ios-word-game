import SwiftUI

enum ParchmentOverlayStyle {
    enum Tunables {
        static let cardSpacing: CGFloat = 12
        static let panelShadowRadius: CGFloat = 14
        static let panelShadowY: CGFloat = 10
        static let cardShadowRadius: CGFloat = 6
        static let cardShadowY: CGFloat = 4
        static let cardPressScale: CGFloat = 0.975
        static let cardSelectionFlashDuration: TimeInterval = 0.14
        static let cardSelectionCommitDelay: TimeInterval = 0.16
    }

    enum Radius {
        static let panel: CGFloat = 26
        static let card: CGFloat = 18
        static let chip: CGFloat = 999
        static let stat: CGFloat = 14
    }

    enum Stroke {
        static let panel: CGFloat = 4
        static let card: CGFloat = 3
        static let chip: CGFloat = 1.5
    }
}

struct ParchmentPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ParchmentOverlayStyle.Tunables.cardPressScale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
