import Foundation

final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    func playSelection() {
        guard AppSettings.soundEnabled else { return }
    }

    func playClear() {
        guard AppSettings.soundEnabled else { return }
    }

    func playCascade() {
        guard AppSettings.soundEnabled else { return }
    }
}
