import Foundation
import SwiftData

enum WatchlistItemKind: String, Codable {
    case company
    case fund
}

@Model
final class Watchlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WatchlistItem.watchlist)
    var items: [WatchlistItem]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = []
    }
}

@Model
final class WatchlistItem {
    var kindRaw: String
    var cik: String
    var ticker: String?
    var displayName: String
    var addedAt: Date

    var watchlist: Watchlist?

    var kind: WatchlistItemKind {
        get { WatchlistItemKind(rawValue: kindRaw) ?? .company }
        set { kindRaw = newValue.rawValue }
    }

    init(
        kind: WatchlistItemKind,
        cik: String,
        ticker: String? = nil,
        displayName: String,
        addedAt: Date = .now
    ) {
        self.kindRaw = kind.rawValue
        self.cik = cik
        self.ticker = ticker
        self.displayName = displayName
        self.addedAt = addedAt
    }
}

