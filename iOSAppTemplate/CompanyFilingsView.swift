import SwiftUI
import SecEdgarKit

struct CompanyFilingsView: View {
    let client: SECClient
    let company: SECCompany

    @State private var filings: [SECFiling] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var safariLink: SafariLink?


    // Empty selection means "All forms" (no filtering) but nothing is visually preselected.
    @State private var selectedForms: Set<String> = []

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(company.ticker)
                            .font(.title.bold())
                            .fontDesign(.monospaced)
                        Text(company.name)
                            .foregroundStyle(Theme.textSecondary)
                        Text("CIK: \(company.cik)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Forms") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(SECFilingForm.allCases, id: \.rawValue) { form in
                                Toggle(isOn: Binding(
                                    get: { selectedForms.contains(form.rawValue) },
                                    set: { isOn in
                                        if isOn {
                                            selectedForms.insert(form.rawValue)
                                        } else {
                                            selectedForms.remove(form.rawValue)
                                        }
                                        Task { await loadFilings() }
                                    }
                                )) {
                                    Text(form.displayName)
                                        .fontDesign(.monospaced)
                                }
                                .toggleStyle(.button)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if selectedForms.isEmpty {
                        Text("All forms")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                if isLoading {
                    Section {
                        ProgressView("Loading filings…")
                    }
                    .listRowBackground(Theme.surface)
                }

                if let errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorMessage)
                                .foregroundStyle(Theme.error)
                            Button("Open company on SEC") {
                                if let url = companyBrowseURL() {
                                    safariLink = SafariLink(url: url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("Recent Filings") {
                    if filings.isEmpty, !isLoading {
                        ContentUnavailableView(
                            "No filings",
                            systemImage: "doc.text",
                            description: Text("Try enabling more form types.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filings) { filing in
                            NavigationLink {
                                FilingDetailView(client: client, company: company, filing: filing)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(filing.form) — \(filing.filingDateString)")
                                        .font(.headline)
                                        .fontDesign(.monospaced)
                                    if let items = filing.items, !items.isEmpty {
                                        Text("Items: \(items)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Text(filing.accessionNumber)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
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
        .navigationTitle("Filings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadFilings() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reload filings")
            }
        }
        .task {
            await loadFilings()
        }
    }

    private func loadFilings() async {
        isLoading = true
        errorMessage = nil
        do {
            // Empty selection means no filter.
            filings = try await client.listRecentFilings(cik: company.cik, formFilter: selectedForms)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func companyBrowseURL() -> URL? {
        URL(string: "https://www.sec.gov/edgar/browse/?CIK=\(company.cik)")
    }

}

private struct SafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

