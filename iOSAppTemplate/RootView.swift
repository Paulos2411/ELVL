import SwiftUI
import SwiftData
import SecEdgarKit

struct RootView: View {
    let client: SECClient

    private let companyDirectory: SECCompanyDirectory
    private let managerDirectory: SEC13FManagerDirectory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Watchlist.createdAt, order: .reverse)
    private var watchlists: [Watchlist]

    var body: some View {
        TabView {
            NavigationStack {
                WatchlistsView(client: client)
            }
            .tabItem { Label("Lists", systemImage: "star") }

            NavigationStack {
                SearchCompaniesView(client: client, directory: companyDirectory)
            }
            .tabItem { Label("Companies", systemImage: "building.2") }

            NavigationStack {
                FundSearchView(client: client, directory: managerDirectory)
            }
            .tabItem { Label("Funds", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .background(Theme.background)
        .task {
            ensureDefaultWatchlist()
        }
    }

    init(client: SECClient) {
        self.client = client
        self.companyDirectory = SECCompanyDirectory(client: client)
        self.managerDirectory = SEC13FManagerDirectory(client: client)
    }

    private func ensureDefaultWatchlist() {
        if watchlists.isEmpty {
            modelContext.insert(Watchlist(name: "Default"))
        }
    }
}
