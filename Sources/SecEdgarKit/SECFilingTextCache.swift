import Foundation

/// Disk-backed cache for extracted filing plain text (keyed by CIK + accession number).
///
/// This avoids re-downloading/re-parsing long filings (10-K/10-Q) on subsequent opens.
public actor SECFilingTextCache {
    public struct Options: Sendable {
        public var ttl: TimeInterval
        public var cacheDirectoryName: String

        public init(ttl: TimeInterval = 30 * 24 * 60 * 60, cacheDirectoryName: String = "sec_filings_text_cache_v1") {
            self.ttl = ttl
            self.cacheDirectoryName = cacheDirectoryName
        }
    }

    private let options: Options
    private var inMemory: [String: String] = [:]

    public init(options: Options = Options()) {
        self.options = options
    }

    public func getOrFetch(
        cik: String,
        accessionNumber: String,
        fetcher: @Sendable () async throws -> String
    ) async throws -> String {
        let key = cacheKey(cik: cik, accessionNumber: accessionNumber)
        if let cached = inMemory[key] {
            return cached
        }

        if let cached = try loadFromDiskIfFresh(key: key) {
            inMemory[key] = cached
            return cached
        }

        let fresh = try await fetcher()
        try saveToDisk(text: fresh, key: key)
        inMemory[key] = fresh
        return fresh
    }

    public func invalidate(cik: String, accessionNumber: String) async {
        let key = cacheKey(cik: cik, accessionNumber: accessionNumber)
        inMemory[key] = nil
        do {
            let url = try fileURL(forKey: key)
            try? FileManager.default.removeItem(at: url)
        } catch {
            // ignore
        }
    }

    // MARK: - Helpers

    private func cacheKey(cik: String, accessionNumber: String) -> String {
        let trimmedCIK = cik.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccession = accessionNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(trimmedCIK)_\(trimmedAccession.replacingOccurrences(of: "-", with: ""))"
    }

    private func baseDirectoryURL() throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let caches else {
            throw CocoaError(.fileNoSuchFile)
        }
        return caches.appendingPathComponent(options.cacheDirectoryName, isDirectory: true)
    }

    private func fileURL(forKey key: String) throws -> URL {
        let dir = try baseDirectoryURL()
        let safe = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return dir.appendingPathComponent("\(safe).txt")
    }

    private func loadFromDiskIfFresh(key: String) throws -> String? {
        let url = try fileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        if let modified = values.contentModificationDate {
            if Date().timeIntervalSince(modified) > options.ttl {
                return nil
            }
        }

        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    private func saveToDisk(text: String, key: String) throws {
        let url = try fileURL(forKey: key)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = Data(text.utf8)
        try data.write(to: url, options: [.atomic])
    }
}

