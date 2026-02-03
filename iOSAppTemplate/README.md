# iOS 17+ SwiftUI screens (drop-in template)

This folder contains Swift files you can copy into a new Xcode iOS project.

## Xcode setup

1. Create a new project: **iOS → App**
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 17+
   - Devices: iPhone + iPad

2. Add this repo’s Swift package to the project:
   - Xcode: **File → Add Package Dependencies… → Add Local…**
   - Pick the repository root (where `Package.swift` is)

3. Copy these files into your Xcode app target:
   - `ELVLApp.swift`
   - `RootView.swift`
   - `Theme.swift`
   - `WatchlistModels.swift`
   - `WatchlistsView.swift`
   - `WatchlistDetailView.swift`
   - `WatchlistPickerSheet.swift`
   - `SearchCompaniesView.swift`
   - `CompanyFilingsView.swift`
   - `FilingDetailView.swift`
   - `SafariView.swift`
   - `FundSearchView.swift`
   - `FundFilingsView.swift`
   - `FundHoldingsView.swift`

4. Update SEC User-Agent:
   - In `ELVLApp.swift`, set `userAgent` to your app name + contact.

## Notes

- The SEC may throttle/block if User-Agent is missing or generic.
- Companies and filings open directly in an in-app browser; users can share/download from there.
- Funds (13F) search builds a local directory by parsing the SEC quarterly master index; first load can take a bit.
- Next iterations typically add:
  - caching the company list + filings
  - chart summaries (Swift Charts)
  - “Open on SEC” link for the original HTML
