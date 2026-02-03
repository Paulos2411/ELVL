import SwiftUI
import SwiftData
import SecEdgarKit

struct FundSearchView: View {
    let client: SECClient
    let directory: SEC13FManagerDirectory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Watchlist.createdAt, order: .reverse)
    private var watchlists: [Watchlist]

    @State private var query: String = ""
    @State private var managers: [SEC13FManager] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var addingManager: SEC13FManager?

    private var loadedCountText: String {
        managers.isEmpty ? "" : "Loaded \(managers.count) managers"
    }

    private var filtered: [SEC13FManager] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(managers.prefix(100)) }

        let q = normalize(trimmed)
        return managers
            .filter {
                normalize($0.name).contains(q) || $0.cik.contains(trimmed)
            }
            .prefix(200)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    HStack {
                        TextField("Fund / manager name", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .foregroundStyle(Theme.textPrimary)
                        if isLoading { ProgressView() }
                        Button {
                            Task { await loadManagers(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Reload")
                    }
                    if !loadedCountText.isEmpty {
                        Text(loadedCountText)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("Results") {
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No results",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different name.\nTip: first load can take a moment.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filtered) { manager in
                            NavigationLink {
                                FundFilingsView(client: client, manager: manager)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(manager.name)
                                            .font(.headline)
                                            .fontDesign(.monospaced)
                                        Text(manager.cik)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        addingManager = manager
                                    } label: {
                                        Image(systemName: "plus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add to watchlist")
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Funds (13F)")
        .sheet(item: $addingManager) { manager in
            WatchlistPickerSheet(
                title: "Add fund",
                watchlists: watchlists,
                onCreateList: createWatchlist(named:),
                onSelect: { list in
                    addManager(manager, to: list)
                }
            )
        }
        .task {
            if managers.isEmpty {
                await loadManagers(force: false)
            }
        }
    }

    private func loadManagers(force: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            managers = try await directory.managers(forceRefresh: force)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createWatchlist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Watchlist(name: trimmed))
    }

    private func addManager(_ manager: SEC13FManager, to watchlist: Watchlist) {
        if watchlist.items.contains(where: { $0.kind == .fund && $0.cik == manager.cik }) {
            return
        }
        let item = WatchlistItem(kind: .fund, cik: manager.cik, ticker: nil, displayName: manager.name)
        item.watchlist = watchlist
        modelContext.insert(item)
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
