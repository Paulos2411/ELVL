import SwiftUI
import SwiftData
import SecEdgarKit

struct WatchlistsView: View {
    let client: SECClient
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Watchlist.createdAt, order: .reverse)
    private var watchlists: [Watchlist]

    @State private var newListName: String = ""
    @State private var showingCreate: Bool = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                if watchlists.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No watchlists")
                                .font(.headline)
                                .fontDesign(.monospaced)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Create a watchlist to save companies or funds.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Button("Create watchlist") { showingCreate = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Theme.surface)
                }

                ForEach(watchlists) { watchlist in
                    NavigationLink {
                        WatchlistDetailView(client: client, watchlist: watchlist)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(watchlist.name)
                                .font(.headline)
                                .fontDesign(.monospaced)
                            Text("\(watchlist.items.count) items")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(watchlist)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Watchlists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create watchlist")
            }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    Form {
                        Section("Name") {
                            TextField("e.g. Growth", text: $newListName)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("New Watchlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showingCreate = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Create") {
                            createWatchlist()
                            showingCreate = false
                        }
                        .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func createWatchlist() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(Watchlist(name: name))
        newListName = ""
    }
}
