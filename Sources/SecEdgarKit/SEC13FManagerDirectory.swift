import Foundation

/// Builds a searchable directory of 13F managers by parsing the EDGAR quarterly master index.
///
/// This is intentionally simple and offline-cacheable: it provides the CIK + manager name
/// for filers that submitted 13F-HR / 13F-HR/A in the selected quarter.
public actor SEC13FManagerDirectory {
    public struct Options: Sendable {
        public var ttl: TimeInterval
        public var cacheFileName: String
        public var fallbackQuartersToTry: Int

        public init(
            ttl: TimeInterval = 30 * 24 * 60 * 60,
            cacheFileName: String = "sec_13f_managers_cache_v1.json",
            fallbackQuartersToTry: Int = 4
        ) {
            self.ttl = ttl
            self.cacheFileName = cacheFileName
            self.fallbackQuartersToTry = fallbackQuartersToTry
        }
    }

    private let client: SECClient
    private let options: Options

    private var inMemory: [SEC13FManager]?

    public init(client: SECClient, options: Options = Options()) {
        self.client = client
        self.options = options
    }

    public func managers(forceRefresh: Bool = false) async throws -> [SEC13FManager] {
        if !forceRefresh, let inMemory {
            return inMemory
        }

        if !forceRefresh, let cached = try loadFromDiskIfFresh() {
            inMemory = cached
            return cached
        }

        let fresh = try await fetchLatestQuarterManagers()
        try saveToDisk(fresh)
        inMemory = fresh
        return fresh
    }

    // MARK: - Fetch + parse

    private func fetchLatestQuarterManagers() async throws -> [SEC13FManager] {
        var attempts = 0
        var cursor = currentYearQuarter()

        while attempts < max(1, options.fallbackQuartersToTry) {
            do {
                let data = try await fetchMasterIndex(year: cursor.year, quarter: cursor.quarter)
                let managers = try parseManagersFromMasterIndex(data)
                if !managers.isEmpty {
                    return managers
                }
            } catch {
                // Try previous quarter.
            }

            cursor = previousYearQuarter(from: cursor)
            attempts += 1
        }

        // If everything failed, throw the last error by forcing one more attempt.
        let data = try await fetchMasterIndex(year: cursor.year, quarter: cursor.quarter)
        return try parseManagersFromMasterIndex(data)
    }

    private func fetchMasterIndex(year: Int, quarter: Int) async throws -> Data {
        // Example:
        // https://www.sec.gov/Archives/edgar/full-index/2024/QTR1/master.idx
        let url = URL(string: "https://www.sec.gov/Archives/edgar/full-index/\(year)/QTR\(quarter)/master.idx")
        guard let url else { throw SECClient.SECError.invalidURL }

        // Reuse SECClient's headers via a simple fetch.
        // (SECClient doesn't currently expose a raw fetch, so use URLSession + same UA.)
        // For consistency and rate limits, keep the same User-Agent.
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SECClient.SECError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SECClient.SECError.httpStatus(http.statusCode)
        }
        return data
    }

    private func parseManagersFromMasterIndex(_ data: Data) throws -> [SEC13FManager] {
        // Format (pipe-delimited) after header:
        // CIK|Company Name|Form Type|Date Filed|Filename
        let text = String(decoding: data, as: UTF8.self)
        var managersByCIK: [String: String] = [:]

        for line in text.split(separator: "\n") {
            if line.hasPrefix("CIK|") || line.hasPrefix("Description") || line.hasPrefix("----") {
                continue
            }
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 5 else { continue }

            let cik = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let form = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Some managers file 13F-NT (notice) instead of a full holdings report.
            if form != "13F-HR" && form != "13F-HR/A" && form != "13F-NT" && form != "13F-NT/A" {
                continue
            }
            if cik.isEmpty || name.isEmpty {
                continue
            }
            managersByCIK[cik] = name
        }

        return managersByCIK
            .map { cik, name in SEC13FManager(cik: String(format: "%010d", Int(cik) ?? 0), name: name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func currentYearQuarter() -> (year: Int, quarter: Int) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let quarter = ((month - 1) / 3) + 1
        return (year, quarter)
    }

    private func previousYearQuarter(from current: (year: Int, quarter: Int)) -> (year: Int, quarter: Int) {
        if current.quarter > 1 {
            return (current.year, current.quarter - 1)
        }
        return (current.year - 1, 4)
    }

    // MARK: - Disk cache

    private func cacheURL() throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else { throw CocoaError(.fileNoSuchFile) }
        return base.appendingPathComponent(options.cacheFileName)
    }

    private func loadFromDiskIfFresh() throws -> [SEC13FManager]? {
        let url = try cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        if let modified = values.contentModificationDate {
            if Date().timeIntervalSince(modified) > options.ttl {
                return nil
            }
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SEC13FManager].self, from: data)
    }

    private func saveToDisk(_ managers: [SEC13FManager]) throws {
        let url = try cacheURL()
        let data = try JSONEncoder().encode(managers)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}
