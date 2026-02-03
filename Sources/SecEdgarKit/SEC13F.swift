import Foundation

public struct SEC13FManager: Sendable, Codable, Hashable, Identifiable {
    public let cik: String
    public let name: String

    public var id: String { cik }

    public init(cik: String, name: String) {
        self.cik = cik
        self.name = name
    }
}

public struct SEC13FHolding: Sendable, Codable, Hashable, Identifiable {
    public let issuer: String
    public let titleOfClass: String?
    public let cusip: String?
    public let valueUSDThousands: Int?
    public let sharesOrPrincipalAmount: Int?
    public let sharesOrPrincipalType: String?
    public let putOrCall: String?
    public let investmentDiscretion: String?
    public let votingAuthoritySole: Int?
    public let votingAuthorityShared: Int?
    public let votingAuthorityNone: Int?

    public var id: String {
        // Good-enough stable identifier for list rendering.
        [issuer, cusip ?? "", titleOfClass ?? ""].joined(separator: "|")
    }

    public init(
        issuer: String,
        titleOfClass: String?,
        cusip: String?,
        valueUSDThousands: Int?,
        sharesOrPrincipalAmount: Int?,
        sharesOrPrincipalType: String?,
        putOrCall: String?,
        investmentDiscretion: String?,
        votingAuthoritySole: Int?,
        votingAuthorityShared: Int?,
        votingAuthorityNone: Int?
    ) {
        self.issuer = issuer
        self.titleOfClass = titleOfClass
        self.cusip = cusip
        self.valueUSDThousands = valueUSDThousands
        self.sharesOrPrincipalAmount = sharesOrPrincipalAmount
        self.sharesOrPrincipalType = sharesOrPrincipalType
        self.putOrCall = putOrCall
        self.investmentDiscretion = investmentDiscretion
        self.votingAuthoritySole = votingAuthoritySole
        self.votingAuthorityShared = votingAuthorityShared
        self.votingAuthorityNone = votingAuthorityNone
    }
}
