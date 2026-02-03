import SwiftUI
import SwiftData
import SecEdgarKit

import UIKit

@main
struct ELVLApp: App {
    /// SEC requires a descriptive User-Agent. Replace with your app + contact.
    private let secClient = SECClient(
        configuration: .init(userAgent: "ELVL/1.0 (support@yourdomain.com)")
    )

    init() {
        let accent = UIColor(Theme.accent)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.background)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accent

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.background)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = accent
    }

    var body: some Scene {
        WindowGroup {
            RootView(client: secClient)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Watchlist.self, WatchlistItem.self])
    }
}
