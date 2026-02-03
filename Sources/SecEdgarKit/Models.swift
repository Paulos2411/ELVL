import Foundation

public struct SECCompany: Sendable, Codable, Hashable, Identifiable {
    public let cik: String
    public let ticker: String
    public let name: String

    public var id: String { cik }

    public init(cik: String, ticker: String, name: String) {
        self.cik = cik
        self.ticker = ticker
        self.name = name
    }
}

public struct SECFiling: Sendable, Codable, Hashable, Identifiable {
    public let accessionNumber: String
    public let form: String
    public let filedAt: Date
    public let reportDate: Date?
    public let primaryDocument: String?
    public let items: String?
    public let filingDateString: String

    public var id: String { accessionNumber }

    public init(
        accessionNumber: String,
        form: String,
        filedAt: Date,
        reportDate: Date?,
        primaryDocument: String?,
        items: String?,
        filingDateString: String
    ) {
        self.accessionNumber = accessionNumber
        self.form = form
        self.filedAt = filedAt
        self.reportDate = reportDate
        self.primaryDocument = primaryDocument
        self.items = items
        self.filingDateString = filingDateString
    }
}

public enum SECFilingForm: String, CaseIterable, Sendable {
    case tenK = "10-K"
    case tenQ = "10-Q"
    case eightK = "8-K"
    case form3 = "3"
    case form4 = "4"
    case form5 = "5"
    case thirteenD = "SC 13D"
    case thirteenG = "SC 13G"

    public var displayName: String { rawValue }
}

