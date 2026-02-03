import SwiftUI
import SecEdgarKit

struct SidebarView: View {
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        List {
            Section("Watchlist") {
                if favorites.favorites.isEmpty {
                    Text("No favorites yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(favorites.favorites) { company in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(company.ticker).font(.headline)
                            Text(company.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("SEC Filings")
    }
}

