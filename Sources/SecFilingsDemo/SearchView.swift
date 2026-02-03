import SwiftUI
import SecEdgarKit

struct SearchView: View {
    let client: SECClient
    @ObservedObject var favorites: FavoritesStore

    private let directory: SECCompanyDirectory

    @State private var query: String = ""
    @State private var companies: [SECCompany] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private var filtered: [SECCompany] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Array(companies.prefix(50)) }
        return companies
            .filter {
                $0.ticker.localizedCaseInsensitiveContains(q) ||
                $0.name.localizedCaseInsensitiveContains(q)
            }
            .prefix(100)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search ticker or company name", text: $query)
                    .textFieldStyle(.roundedBorder)
                if isLoading {
                    ProgressView()
                }
                Button("Reload") {
                    Task { await loadCompanies() }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            List(filtered) { company in
                NavigationLink {
                    CompanyDetailView(client: client, company: company)
                        .toolbar {
                            Button {
                                favorites.toggle(company)
                            } label: {
                                Text(favorites.isFavorite(company) ? "★" : "☆")
                            }
                        }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(company.ticker).font(.headline)
                            Text(company.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(favorites.isFavorite(company) ? "★" : "")
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Search")
        .task {
            if companies.isEmpty {
                await loadCompanies()
            }
        }
    }

    init(client: SECClient, favorites: FavoritesStore) {
        self.client = client
        self.favorites = favorites
        self.directory = SECCompanyDirectory(client: client)
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
}
