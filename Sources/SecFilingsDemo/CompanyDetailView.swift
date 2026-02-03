import SwiftUI
import SecEdgarKit

struct CompanyDetailView: View {
    let client: SECClient
    let company: SECCompany

    @State private var filings: [SECFiling] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedForms: Set<String> = Set(SECFilingForm.allCases.map { $0.rawValue })

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(company.ticker).font(.largeTitle.bold())
                Text(company.name).foregroundStyle(.secondary)
                Text("CIK: \(company.cik)").font(.caption).foregroundStyle(.secondary)
            }

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
                        }
                        .toggleStyle(.button)
                    }
                }
            }

            if isLoading {
                ProgressView("Loading filings…")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            List(filings) { filing in
                NavigationLink {
                    FilingDetailView(client: client, company: company, filing: filing)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(filing.form) — \(filing.filingDateString)").font(.headline)
                        Text(filing.accessionNumber)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Filings")
        .task { await loadFilings() }
    }

    private func loadFilings() async {
        isLoading = true
        errorMessage = nil
        do {
            let filter = selectedForms
            filings = try await client.listRecentFilings(cik: company.cik, formFilter: filter)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

