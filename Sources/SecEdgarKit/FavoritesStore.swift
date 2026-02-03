import Foundation

@MainActor
public final class FavoritesStore: ObservableObject {
    @Published public private(set) var favorites: [SECCompany] = []

    private let userDefaults: UserDefaults
    private let key = "SecFilings.favorites.v1"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    public func isFavorite(_ company: SECCompany) -> Bool {
        favorites.contains(company)
    }

    public func toggle(_ company: SECCompany) {
        if let idx = favorites.firstIndex(of: company) {
            favorites.remove(at: idx)
        } else {
            favorites.append(company)
            favorites.sort { $0.ticker.localizedCaseInsensitiveCompare($1.ticker) == .orderedAscending }
        }
        persist()
    }

    private func load() {
        guard let data = userDefaults.data(forKey: key) else {
            favorites = []
            return
        }
        favorites = (try? JSONDecoder().decode([SECCompany].self, from: data)) ?? []
    }

    private func persist() {
        let data = try? JSONEncoder().encode(favorites)
        userDefaults.setValue(data, forKey: key)
    }
}

