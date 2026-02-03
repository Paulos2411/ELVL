import SwiftUI
import SwiftData
import SecEdgarKit

struct SearchCompaniesView: View {
    let client: SECClient
    let directory: SECCompanyDirectory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Watchlist.createdAt, order: .reverse)
    private var watchlists: [Watchlist]

    @State private var query: String = ""
    @State private var companies: [SECCompany] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var addingCompany: SECCompany?

    private var filtered: [SECCompany] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(companies.prefix(50))
        }

        return companies
            .filter {
                $0.ticker.localizedCaseInsensitiveContains(trimmed) ||
                $0.name.localizedCaseInsensitiveContains(trimmed)
            }
            .prefix(150)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    HStack {
                        TextField("Ticker or company name", text: $query)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .foregroundStyle(Theme.textPrimary)

                        if isLoading {
                            ProgressView()
                        }

                        Button {
                            Task { await loadCompanies() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Reload companies")
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
                            description: Text("Try a different ticker or name.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filtered) { company in
                            NavigationLink {
                                CompanyFilingsView(client: client, company: company)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(company.ticker)
                                            .font(.headline)
                                            .fontDesign(.monospaced)
                                        Text(company.name)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        addingCompany = company
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
        .navigationTitle("Companies")
        .sheet(item: $addingCompany) { company in
            WatchlistPickerSheet(
                title: "Add \(company.ticker)",
                watchlists: watchlists,
                onCreateList: createWatchlist(named:),
                onSelect: { list in
                    addCompany(company, to: list)
                }
            )
        }
        .task {
            if companies.isEmpty {
                await loadCompanies()
            }
        }
    }

    private func loadCompanies() async {
        isLoading = true
        errorMessage = nil
        do {
            companies = try await directory.companies()
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

    private func addCompany(_ company: SECCompany, to watchlist: Watchlist) {
        if watchlist.items.contains(where: { $0.kind == .company && $0.cik == company.cik }) {
            return
        }
        let item = WatchlistItem(kind: .company, cik: company.cik, ticker: company.ticker, displayName: company.name)
        item.watchlist = watchlist
        modelContext.insert(item)
    }
}
