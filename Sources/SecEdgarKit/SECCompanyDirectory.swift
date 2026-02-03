import Foundation

/// Caches the SEC ticker→CIK company directory on-device.
///
/// The SEC company directory changes, but not minute-to-minute; caching avoids re-downloading
/// the full mapping on every app launch.
public actor SECCompanyDirectory {
    public struct Options: Sendable {
        public var ttl: TimeInterval
        public var cacheFileName: String

        public init(ttl: TimeInterval = 7 * 24 * 60 * 60, cacheFileName: String = "sec_company_tickers_cache_v1.json") {
            self.ttl = ttl
            self.cacheFileName = cacheFileName
        }
    }

    private let client: SECClient
    private let options: Options

    private var inMemory: [SECCompany]?

    public init(client: SECClient, options: Options = Options()) {
        self.client = client
        self.options = options
    }

    public func companies(forceRefresh: Bool = false) async throws -> [SECCompany] {
        if !forceRefresh, let inMemory {
            return inMemory
        }

        if !forceRefresh, let cached = try loadFromDiskIfFresh() {
            inMemory = cached
            return cached
        }

        let fresh = try await client.fetchCompanies()
        try saveToDisk(fresh)
        inMemory = fresh
        return fresh
    }

    // MARK: - Disk cache

    private func cacheURL() throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appendingPathComponent(options.cacheFileName)
    }

    private func loadFromDiskIfFresh() throws -> [SECCompany]? {
        let url = try cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        if let modified = values.contentModificationDate {
            if Date().timeIntervalSince(modified) > options.ttl {
                return nil
            }
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SECCompany].self, from: data)
    }

    private func saveToDisk(_ companies: [SECCompany]) throws {
        let url = try cacheURL()
        let data = try JSONEncoder().encode(companies)

        // Ensure directory exists.
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try data.write(to: url, options: [.atomic])
    }
}

