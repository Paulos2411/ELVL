import Foundation

public enum SEC13FHoldingsParser {
    public static func parse(xml data: Data) throws -> [SEC13FHolding] {
        // SEC may return HTML/text error pages when throttled.
        let prefix = String(decoding: data.prefix(200), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if prefix.hasPrefix("<html") || prefix.contains("<head") {
            throw SECClient.SECError.unexpectedContent("Got HTML instead of 13F XML. Check User-Agent and rate limits.")
        }

        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? SECClient.SECError.decodingFailed
        }
        return delegate.holdings
    }
}

private final class Delegate: NSObject, XMLParserDelegate {
    fileprivate var holdings: [SEC13FHolding] = []

    private var currentElement: String = ""
    private var currentText: String = ""
    private var current: Builder?

    private struct Builder {
        var issuer: String = ""
        var titleOfClass: String?
        var cusip: String?
        var value: Int?
        var shares: Int?
        var sharesType: String?
        var putCall: String?
        var investmentDiscretion: String?
        var votingSole: Int?
        var votingShared: Int?
        var votingNone: Int?
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        // The SEC information table uses `<infoTable>` elements.
        if elementName.lowercased() == "infotable" {
            current = Builder()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            currentElement = ""
            currentText = ""
        }

        guard var builder = current else {
            return
        }

        let key = elementName.lowercased()
        switch key {
        case "nameofissuer":
            builder.issuer = value
        case "titleofclass":
            builder.titleOfClass = value
        case "cusip":
            builder.cusip = value
        case "value":
            builder.value = Int(value)
        case "sshprnamt":
            builder.shares = Int(value)
        case "sshprnamttype":
            builder.sharesType = value
        case "putcall":
            builder.putCall = value
        case "investmentdiscretion":
            builder.investmentDiscretion = value
        case "sole":
            builder.votingSole = Int(value)
        case "shared":
            builder.votingShared = Int(value)
        case "none":
            builder.votingNone = Int(value)
        case "infotable":
            if !builder.issuer.isEmpty {
                holdings.append(
                    SEC13FHolding(
                        issuer: builder.issuer,
                        titleOfClass: builder.titleOfClass,
                        cusip: builder.cusip,
                        valueUSDThousands: builder.value,
                        sharesOrPrincipalAmount: builder.shares,
                        sharesOrPrincipalType: builder.sharesType,
                        putOrCall: builder.putCall,
                        investmentDiscretion: builder.investmentDiscretion,
                        votingAuthoritySole: builder.votingSole,
                        votingAuthorityShared: builder.votingShared,
                        votingAuthorityNone: builder.votingNone
                    )
                )
            }
            current = nil
            return
        default:
            break
        }

        current = builder
    }
}
