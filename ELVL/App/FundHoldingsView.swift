import SwiftUI
import SecEdgarKit

struct FundHoldingsView: View {
    let client: SECClient
    let manager: SEC13FManager
    let filing: SECFiling

    @State private var holdings: [SEC13FHolding] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var query: String = ""
    @State private var safariLink: SafariLink?

    private var filtered: [SEC13FHolding] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return holdings }
        return holdings.filter { $0.issuer.localizedCaseInsensitiveContains(trimmed) || ($0.cusip ?? "").localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Holdings")
                            .font(.title3.bold())
                            .fontDesign(.monospaced)
                        Text("\(filing.form) — \(filing.filingDateString)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    TextField("Search holdings", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Theme.surface)

                if isLoading {
                    Section {
                        ProgressView("Loading…")
                    }
                    .listRowBackground(Theme.surface)
                }

                if let errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorMessage)
                                .foregroundStyle(Theme.error)
                            Button("Open filing on SEC") {
                                if let url = filingURL() {
                                    safariLink = SafariLink(url: url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("Positions") {
                    ForEach(filtered) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.issuer)
                                .font(.headline)
                                .fontDesign(.monospaced)
                            HStack {
                                if let value = row.valueUSDThousands {
                                    Text("$\(value)k")
                                }
                                if let shares = row.sharesOrPrincipalAmount {
                                    Text("\(shares)")
                                    if let t = row.sharesOrPrincipalType {
                                        Text(t)
                                    }
                                }
                                if let cusip = row.cusip {
                                    Text(cusip)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("13F Holdings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            holdings = try await client.fetch13FHoldings(cik: manager.cik, accessionNumber: filing.accessionNumber)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func filingURL() -> URL? {
        let cikNoZeros = String(Int(manager.cik) ?? 0)
        let accessionNoDashes = filing.accessionNumber.replacingOccurrences(of: "-", with: "")
        let base = "https://www.sec.gov/Archives/edgar/data/\(cikNoZeros)/\(accessionNoDashes)/"

        if let primary = filing.primaryDocument {
            let lower = primary.lowercased()
            if lower.hasSuffix(".htm") || lower.hasSuffix(".html") {
                return URL(string: base + primary)
            }
        }

        return URL(string: base + "index.html")
    }
}

private struct SafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

