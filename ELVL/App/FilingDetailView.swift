import SwiftUI
import SecEdgarKit

/// Opens a filing directly in an in-app browser.
///
/// This view resolves the best single HTML document to open (not the filing index).
struct FilingDetailView: View {
    let client: SECClient
    let company: SECCompany
    let filing: SECFiling

    @State private var url: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let url {
                SafariView(url: url)
                    .ignoresSafeArea()
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could not open filing",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Opening…")
            }
        }
        .navigationTitle("\(filing.form)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
            }
        }
        .task {
            if url == nil, errorMessage == nil {
                await resolveURL()
            }
        }
    }

    @MainActor
    private func resolveURL() async {
        do {
            url = try await bestSingleHTMLURLToOpen()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bestSingleHTMLURLToOpen() async throws -> URL {
        let cikNoZeros = String(Int(company.cik) ?? 0)
        let accessionNoDashes = filing.accessionNumber.replacingOccurrences(of: "-", with: "")
        let base = "https://www.sec.gov/Archives/edgar/data/\(cikNoZeros)/\(accessionNoDashes)/"

        // Prefer the filing's primary document without needing `index.json`.
        // This is more reliable (avoids extra SEC JSON requests that can be blocked).
        if let primary = filing.primaryDocument {
            if let url = URL(string: base + primary) {
                return url
            }
        }

        // Last resort: the filing directory index.
        guard let url = URL(string: base + "index.html") else {
            throw URLError(.badURL)
        }
        return url
    }
}
