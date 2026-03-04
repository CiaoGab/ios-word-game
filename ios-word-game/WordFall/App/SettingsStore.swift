import SwiftUI
import Combine
import Foundation

enum AppSettings {
    enum Keys {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let soundEnabled = "settings.soundEnabled"
        static let reduceMotion = "settings.reduceMotion"
        static let highContrast = "settings.highContrast"
    }

    enum Defaults {
        static let hapticsEnabled = true
        static let soundEnabled = true
        static let reduceMotion = false
        static let highContrast = false
    }

    private static let store = UserDefaults.standard

    private static func boolValue(forKey key: String, fallback: Bool) -> Bool {
        guard store.object(forKey: key) != nil else { return fallback }
        return store.bool(forKey: key)
    }

    static var hapticsEnabled: Bool {
        boolValue(forKey: Keys.hapticsEnabled, fallback: Defaults.hapticsEnabled)
    }

    static var soundEnabled: Bool {
        boolValue(forKey: Keys.soundEnabled, fallback: Defaults.soundEnabled)
    }

    static var reduceMotion: Bool {
        boolValue(forKey: Keys.reduceMotion, fallback: Defaults.reduceMotion)
    }

    static var highContrast: Bool {
        boolValue(forKey: Keys.highContrast, fallback: Defaults.highContrast)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let didChangeNotification = Notification.Name("SettingsStore.didChange")

    @AppStorage(AppSettings.Keys.hapticsEnabled) var hapticsEnabled: Bool = AppSettings.Defaults.hapticsEnabled {
        didSet { notifySettingChanged() }
    }

    @AppStorage(AppSettings.Keys.soundEnabled) var soundEnabled: Bool = AppSettings.Defaults.soundEnabled {
        didSet { notifySettingChanged() }
    }

    @AppStorage(AppSettings.Keys.reduceMotion) var reduceMotion: Bool = AppSettings.Defaults.reduceMotion {
        didSet { notifySettingChanged() }
    }

    @AppStorage(AppSettings.Keys.highContrast) var highContrast: Bool = AppSettings.Defaults.highContrast {
        didSet { notifySettingChanged() }
    }

    private init() {}

    private func notifySettingChanged() {
        objectWillChange.send()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
