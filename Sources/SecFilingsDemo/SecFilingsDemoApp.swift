import SwiftUI
import SecEdgarKit

@main
struct SecFilingsDemoApp: App {
    private let client = SECClient(
        configuration: .init(userAgent: "SecFilingsDemo/0.1 (contact: you@example.com)")
    )

    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(favorites: favorites)
            } detail: {
                SearchView(client: client, favorites: favorites)
            }
        }
    }
}

