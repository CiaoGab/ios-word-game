import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}
#endif

@main
struct WordFallApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appOrientationDelegate
    #endif

    init() {
        // Pre-warm the audio engine at app launch so the first gameplay interaction
        // never triggers engine setup. Avoids first-tap latency and init-time crashes.
        SoundManager.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
