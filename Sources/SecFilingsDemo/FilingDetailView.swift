import SwiftUI
import SecEdgarKit

struct FilingDetailView: View {
    let client: SECClient
    let company: SECCompany
    let filing: SECFiling

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var text: String = ""

    #if canImport(AVFoundation)
    @StateObject private var reader = SpeechReader()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Filing") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Form: \(filing.form)")
                    Text("Filed: \(filing.filingDateString)")
                    Text("Accession: \(filing.accessionNumber)")
                    if let doc = filing.primaryDocument {
                        Text("Primary doc: \(doc)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(isLoading ? "Loading…" : "Load full text") {
                    Task { await loadText() }
                }
                .disabled(isLoading)

                #if canImport(AVFoundation)
                Button("Read") { reader.speak() }
                    .disabled(text.isEmpty)
                Button("Pause") { reader.pause() }
                    .disabled(text.isEmpty)
                Button("Stop") { reader.stop() }
                    .disabled(text.isEmpty)
                ProgressView(value: reader.progress)
                    .frame(width: 140)
                #endif
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            ScrollView {
                Text(text.isEmpty ? "(Load a filing to display text)" : text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)
            }
        }
        .padding()
        .navigationTitle("\(filing.form)")
    }

    private func loadText() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await client.fetchFilingFullText(
                cik: company.cik,
                accessionNumber: filing.accessionNumber,
                primaryDocumentHint: filing.primaryDocument
            )
            text = loaded

            #if canImport(AVFoundation)
            reader.load(text: loaded)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}


