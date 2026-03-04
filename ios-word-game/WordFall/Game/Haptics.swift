import UIKit

enum Haptics {
    private static let selectionGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let submitGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        guard AppSettings.hapticsEnabled else { return }
        selectionGenerator.prepare()
        submitGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Fire on each tile added or removed from the active path.
    static func selectionStep() {
        guard AppSettings.hapticsEnabled else { return }
        selectionGenerator.impactOccurred()
    }

    /// Fire on a successfully accepted word submission.
    static func submitAcceptedLight() {
        guard AppSettings.hapticsEnabled else { return }
        submitGenerator.impactOccurred()
    }

    /// Fire when the round objective is met.
    static func notifyRoundClearSuccess() {
        guard AppSettings.hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    /// Fire on a rejected word submission.
    static func notifyWarning() {
        guard AppSettings.hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
}
