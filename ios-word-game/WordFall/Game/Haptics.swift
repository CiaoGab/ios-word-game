import UIKit

enum Haptics {
    private static let selectionGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Fire on each tile added or removed from the active path.
    static func selectionStep() {
        selectionGenerator.impactOccurred()
    }

    /// Fire on a successfully accepted word submission.
    static func notifySuccess() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Fire on a rejected word submission.
    static func notifyWarning() {
        notificationGenerator.notificationOccurred(.warning)
    }
}
