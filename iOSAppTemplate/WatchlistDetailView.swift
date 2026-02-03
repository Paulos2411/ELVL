import SwiftUI
import SwiftData
import SecEdgarKit

struct WatchlistDetailView: View {
    let client: SECClient
    let watchlist: Watchlist

    @Environment(\.modelContext) private var modelContext

    @State private var showingRename: Bool = false
    @State private var newName: String = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                if watchlist.items.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Empty watchlist")
                                .font(.headline)
                                .fontDesign(.monospaced)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Add companies or 13F funds from search.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Theme.surface)
                }

                ForEach(watchlist.items.sorted(by: { $0.addedAt > $1.addedAt })) { item in
                    NavigationLink {
                        destinationView(for: item)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.ticker ?? item.displayName)
                                    .font(.headline)
                                    .fontDesign(.monospaced)
                                if item.ticker != nil {
                                    Text(item.displayName)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                } else {
                                    Text(item.cik)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Text(item.kind == .fund ? "13F" : "")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(watchlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = watchlist.name
                    showingRename = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Rename")
            }
        }
        .sheet(isPresented: $showingRename) {
            NavigationStack {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    Form {
                        Section("Name") {
                            TextField("Name", text: $newName)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("Rename")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showingRename = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                watchlist.name = trimmed
                            }
                            showingRename = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for item: WatchlistItem) -> some View {
        switch item.kind {
        case .company:
            CompanyFilingsView(client: client, company: SECCompany(cik: item.cik, ticker: item.ticker ?? "", name: item.displayName))
        case .fund:
            FundFilingsView(client: client, manager: SEC13FManager(cik: item.cik, name: item.displayName))
        }
    }
}

