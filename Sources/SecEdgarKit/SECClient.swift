import Foundation

public struct SECClient: Sendable {
    public struct Configuration: Sendable {
        public var userAgent: String
        public var timeout: TimeInterval

        public init(userAgent: String, timeout: TimeInterval = 30) {
            self.userAgent = userAgent
            self.timeout = timeout
        }
    }

    public enum SECError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case decodingFailed
        case unexpectedContent(String)
        case missingCIK

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL."
            case .invalidResponse:
                return "Invalid network response."
            case .httpStatus(let code):
                return "SEC request failed with HTTP status \(code)."
            case .decodingFailed:
                return "Failed to decode SEC response."
            case .unexpectedContent(let hint):
                return "SEC returned unexpected content. \(hint)"
            case .missingCIK:
                return "Missing CIK for selected company."
            }
        }
    }

    private let configuration: Configuration
    private let urlSession: URLSession

    private let jsonDecoder: JSONDecoder
    private let dateFormatter: DateFormatter

    public init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession

        let decoder = JSONDecoder()
        self.jsonDecoder = decoder

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = df
    }

    public var userAgent: String {
        configuration.userAgent
    }

    public func fetchCompanies() async throws -> [SECCompany] {
        // Official mapping used widely:
        // https://www.sec.gov/files/company_tickers.json
        let url = URL(string: "https://www.sec.gov/files/company_tickers.json")
        guard let url else { throw SECError.invalidURL }

        let data = try await fetchData(url: url)

        // Response shape: {"0":{"cik_str":320193,"ticker":"AAPL","title":"Apple Inc."}, ...}
        struct CompanyRow: Decodable {
            let cik_str: Int
            let ticker: String
            let title: String
        }

        let decoded = try jsonDecoder.decode([String: CompanyRow].self, from: data)
        return decoded
            .values
            .map { row in
                SECCompany(
                    cik: String(format: "%010d", row.cik_str),
                    ticker: row.ticker,
                    name: row.title
                )
            }
            .sorted { $0.ticker.localizedCaseInsensitiveCompare($1.ticker) == .orderedAscending }
    }

    public func fetchCompanySubmissions(cik: String) async throws -> CompanySubmissions {
        // https://data.sec.gov/submissions/CIK##########.json
        let paddedCIK = cik.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "https://data.sec.gov/submissions/CIK\(paddedCIK).json")
        guard let url else { throw SECError.invalidURL }

        let data = try await fetchData(url: url)
        do {
            return try jsonDecoder.decode(CompanySubmissions.self, from: data)
        } catch {
            throw contentAwareDecodingError(data)
        }
    }

    public func listRecentFilings(
        cik: String,
        formFilter: Set<String> = []
    ) async throws -> [SECFiling] {
        let submissions = try await fetchCompanySubmissions(cik: cik)
        let recent = submissions.filings.recent

        var results: [SECFiling] = []
        results.reserveCapacity(recent.accessionNumber.count)

        for idx in 0..<recent.accessionNumber.count {
            let form = recent.form[safe: idx] ?? ""
            if !formFilter.isEmpty, !formFilter.contains(form) {
                continue
            }

            let filingDateString = recent.filingDate[safe: idx] ?? ""
            guard let filedAt = dateFormatter.date(from: filingDateString) else {
                continue
            }

            let reportDateString = recent.reportDate?[safe: idx]
            let reportDate = reportDateString.flatMap { dateFormatter.date(from: $0) }

            results.append(
                SECFiling(
                    accessionNumber: recent.accessionNumber[idx],
                    form: form,
                    filedAt: filedAt,
                    reportDate: reportDate,
                    primaryDocument: recent.primaryDocument?[safe: idx],
                    items: recent.items?[safe: idx],
                    filingDateString: filingDateString
                )
            )
        }

        return results.sorted { $0.filedAt > $1.filedAt }
    }

    public func filingIndex(cik: String, accessionNumber: String) async throws -> FilingIndex {
        // https://www.sec.gov/Archives/edgar/data/{cikNoZeros}/{accessionNoDashes}/index.json
        let cikNoZeros = String(Int(cik) ?? 0)
        let accessionNoDashes = accessionNumber.replacingOccurrences(of: "-", with: "")

        let url = URL(string: "https://www.sec.gov/Archives/edgar/data/\(cikNoZeros)/\(accessionNoDashes)/index.json")
        guard let url else { throw SECError.invalidURL }
        let data = try await fetchData(url: url)
        do {
            return try jsonDecoder.decode(FilingIndex.self, from: data)
        } catch {
            throw contentAwareDecodingError(data)
        }
    }

    public func filingArchiveDirectoryURL(cik: String, accessionNumber: String) throws -> URL {
        // https://www.sec.gov/Archives/edgar/data/{cikNoZeros}/{accessionNoDashes}/
        let cikNoZeros = String(Int(cik) ?? 0)
        let accessionNoDashes = accessionNumber.replacingOccurrences(of: "-", with: "")
        guard let url = URL(string: "https://www.sec.gov/Archives/edgar/data/\(cikNoZeros)/\(accessionNoDashes)/") else {
            throw SECError.invalidURL
        }
        return url
    }

    public func filingDocumentURL(cik: String, accessionNumber: String, filename: String) throws -> URL {
        let base = try filingArchiveDirectoryURL(cik: cik, accessionNumber: accessionNumber)
        return base.appendingPathComponent(filename)
    }

    public func bestFilingHTMLURL(
        cik: String,
        accessionNumber: String,
        primaryDocumentHint: String? = nil
    ) async throws -> URL {
        if let hint = primaryDocumentHint {
            let lower = hint.lowercased()
            if lower.hasSuffix(".htm") || lower.hasSuffix(".html") {
                return try filingDocumentURL(cik: cik, accessionNumber: accessionNumber, filename: hint)
            }
        }

        let index = try await filingIndex(cik: cik, accessionNumber: accessionNumber)
        if let htmlFile = index.directory.item.first(where: { $0.name.lowercased().hasSuffix(".htm") || $0.name.lowercased().hasSuffix(".html") }) {
            return try filingDocumentURL(cik: cik, accessionNumber: accessionNumber, filename: htmlFile.name)
        }

        throw SECError.invalidResponse
    }

    public func fetchFilingPrimaryDocumentHTML(
        cik: String,
        accessionNumber: String,
        primaryDocument: String
    ) async throws -> Data {
        let url = try filingDocumentURL(cik: cik, accessionNumber: accessionNumber, filename: primaryDocument)
        return try await fetchData(url: url)
    }

    public func fetchFilingFullText(
        cik: String,
        accessionNumber: String,
        primaryDocumentHint: String? = nil
    ) async throws -> String {
        // Prefer primary document HTML when available; otherwise fall back to the first .htm/.html found in index.json
        if let hint = primaryDocumentHint {
            let data = try await fetchFilingPrimaryDocumentHTML(cik: cik, accessionNumber: accessionNumber, primaryDocument: hint)
            return try HTMLTextExtractor.extractText(fromHTMLData: data)
        }

        let index = try await filingIndex(cik: cik, accessionNumber: accessionNumber)
        if let htmlFile = index.directory.item.first(where: { $0.name.lowercased().hasSuffix(".htm") || $0.name.lowercased().hasSuffix(".html") }) {
            let data = try await fetchFilingPrimaryDocumentHTML(cik: cik, accessionNumber: accessionNumber, primaryDocument: htmlFile.name)
            return try HTMLTextExtractor.extractText(fromHTMLData: data)
        }

        // Fallback: full submission text file.
        if let data = try? await fetchSubmissionTextData(cik: cik, accessionNumber: accessionNumber) {
            return String(decoding: data, as: UTF8.self)
        }

        throw SECError.invalidURL
    }

    public func fetchSubmissionTextData(cik: String, accessionNumber: String) async throws -> Data {
        // https://www.sec.gov/Archives/edgar/data/{cikNoZeros}/{accessionNoDashes}/{accessionNoDashes}.txt
        let cikNoZeros = String(Int(cik) ?? 0)
        let accessionNoDashes = accessionNumber.replacingOccurrences(of: "-", with: "")
        let url = URL(string: "https://www.sec.gov/Archives/edgar/data/\(cikNoZeros)/\(accessionNoDashes)/\(accessionNoDashes).txt")
        guard let url else { throw SECError.invalidURL }
        return try await fetchData(url: url)
    }

    public func fetch13FHoldings(cik: String, accessionNumber: String) async throws -> [SEC13FHolding] {
        // Try common info table filenames first (avoids needing index.json).
        let candidates = [
            "infotable.xml",
            "infoTable.xml",
            "informationtable.xml",
            "informationTable.xml",
            "form13fInfoTable.xml",
            "form13fInformationTable.xml",
        ]

        for candidate in candidates {
            do {
                let data = try await fetchFilingPrimaryDocumentHTML(cik: cik, accessionNumber: accessionNumber, primaryDocument: candidate)
                return try SEC13FHoldingsParser.parse(xml: data)
            } catch let SECError.httpStatus(code) where code == 404 {
                continue
            } catch {
                // If it's not a 404, continue to the index.json approach.
                break
            }
        }

        // Fallback: parse the full submission text and extract the INFORMATION TABLE.
        if let submissionData = try? await fetchSubmissionTextData(cik: cik, accessionNumber: accessionNumber),
           let extractedXML = SEC13FSubmissionExtractor.extractInformationTableXML(from: submissionData) {
            return try SEC13FHoldingsParser.parse(xml: extractedXML)
        }

        // Fallback: locate the infotable file via index.json.
        let index = try await filingIndex(cik: cik, accessionNumber: accessionNumber)

        func isInfoTableXML(_ name: String) -> Bool {
            let lower = name.lowercased()
            guard lower.hasSuffix(".xml") else { return false }
            return lower.contains("infotable") || lower.contains("informationtable")
        }

        let xmlName =
            index.directory.item.first(where: { isInfoTableXML($0.name) })?.name
            ?? index.directory.item.first(where: { $0.name.lowercased().hasSuffix(".xml") })?.name

        guard let xmlName else {
            throw SECError.invalidResponse
        }

        let data = try await fetchFilingPrimaryDocumentHTML(cik: cik, accessionNumber: accessionNumber, primaryDocument: xmlName)
        return try SEC13FHoldingsParser.parse(xml: data)
    }

    private func fetchData(url: URL) async throws -> Data {
        try await fetchData(url: url, attempt: 0)
    }

    private func fetchData(url: URL, attempt: Int) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json,text/html,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SECError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if shouldRetry(statusCode: http.statusCode), attempt < 1 {
                try await Task.sleep(nanoseconds: 1_200_000_000)
                return try await fetchData(url: url, attempt: attempt + 1)
            }
            throw SECError.httpStatus(http.statusCode)
        }

        if let blockMessage = secBlockMessage(from: data) {
            if attempt < 1 {
                try await Task.sleep(nanoseconds: 1_200_000_000)
                return try await fetchData(url: url, attempt: attempt + 1)
            }
            throw SECError.unexpectedContent(blockMessage)
        }

        return data
    }

    private func contentAwareDecodingError(_ data: Data) -> SECError {
        if let blockMessage = secBlockMessage(from: data) {
            return .unexpectedContent(blockMessage)
        }

        // SEC sometimes returns HTML or a plain-text notice when blocked/throttled.
        let prefix = String(decoding: data.prefix(200), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if prefix.hasPrefix("<") {
            return .unexpectedContent("Got HTML instead of JSON. Check User-Agent and rate limits.")
        }
        return .decodingFailed
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 403 || statusCode == 429 || statusCode == 503
    }

    private func secBlockMessage(from data: Data) -> String? {
        let prefix = String(decoding: data.prefix(600), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return nil }

        let lower = prefix.lowercased()
        let indicators = [
            "request rate threshold",
            "rate limit",
            "too many requests",
            "temporarily unavailable",
            "service unavailable",
            "access denied",
            "forbidden",
            "unauthorized",
            "automated",
        ]

        if indicators.contains(where: { lower.contains($0) }) {
            return "SEC rate limit or access blocked. Ensure your User-Agent includes app name + contact, then retry in a minute."
        }

        return nil
    }
}

// MARK: - SEC Submissions JSON

public struct CompanySubmissions: Decodable, Sendable {
    public let cik: String
    public let name: String
    public let tickers: [String]?
    public let exchanges: [String]?
    public let filings: Filings

    public struct Filings: Decodable, Sendable {
        public let recent: Recent
    }

    public struct Recent: Decodable, Sendable {
        public let accessionNumber: [String]
        public let filingDate: [String]
        public let reportDate: [String]?
        public let form: [String]
        public let primaryDocument: [String]?
        public let items: [String]?
    }
}

// MARK: - Filing index.json

public struct FilingIndex: Decodable, Sendable {
    public let directory: Directory

    public struct Directory: Decodable, Sendable {
        public let item: [Item]
    }

    public struct Item: Decodable, Sendable {
        public let name: String
        public let size: Int?
        public let type: String?
        public let lastModified: String?
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
