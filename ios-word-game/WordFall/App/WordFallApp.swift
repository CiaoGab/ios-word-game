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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
