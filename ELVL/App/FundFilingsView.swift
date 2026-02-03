import Foundation
import SwiftUI
import SecEdgarKit

struct FundFilingsView: View {
    let client: SECClient
    let manager: SEC13FManager

    @State private var filings: [SECFiling] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var openingAccession: String?
    @State private var selectedFilingURL: FilingURL?

    struct FilingURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.name)
                            .font(.title3.bold())
                            .fontDesign(.monospaced)
                        Text("CIK: \(manager.cik)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                if isLoading {
                    Section {
                        ProgressView("Loading 13F filings…")
                    }
                    .listRowBackground(Theme.surface)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("13F Filings") {
                    ForEach(filings) { filing in
                        Button {
                            openFiling(filing)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(filing.form) — \(filing.filingDateString)")
                                        .font(.headline)
                                        .fontDesign(.monospaced)
                                    Text(filing.accessionNumber)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if openingAccession == filing.accessionNumber {
                                    ProgressView()
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("13F")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $selectedFilingURL) { item in
            SafariView(url: item.url)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let filter: Set<String> = ["13F-HR", "13F-HR/A", "13F-NT", "13F-NT/A"]
            filings = try await client.listRecentFilings(cik: manager.cik, formFilter: filter)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openFiling(_ filing: SECFiling) {
        openingAccession = filing.accessionNumber
        errorMessage = nil
        Task {
            defer { openingAccession = nil }
            do {
                let url = try await client.bestFilingHTMLURL(
                    cik: manager.cik,
                    accessionNumber: filing.accessionNumber,
                    primaryDocumentHint: filing.primaryDocument
                )
                selectedFilingURL = FilingURL(url: url)
            } catch {
                do {
                    let fallback = try client.filingArchiveDirectoryURL(
                        cik: manager.cik,
                        accessionNumber: filing.accessionNumber
                    )
                    selectedFilingURL = FilingURL(url: fallback)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

