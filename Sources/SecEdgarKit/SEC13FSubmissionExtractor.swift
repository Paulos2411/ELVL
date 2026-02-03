import Foundation

public enum SEC13FSubmissionExtractor {
    /// Extracts the INFORMATION TABLE XML from a full submission text file.
    ///
    /// Many 13F submissions embed the infotable as an attachment in the submission .txt.
    /// This avoids additional `index.json` lookups (which can be throttled).
    public static func extractInformationTableXML(from submissionData: Data) -> Data? {
        // The submission is ASCII-ish; decode lossy.
        let text = String(decoding: submissionData, as: UTF8.self)

        // Locate the attachment marked as INFORMATION TABLE.
        // Common pattern:
        // <TYPE>INFORMATION TABLE
        // <TEXT>
        // <?xml ...> ...
        // </TEXT>
        let typeRange = text.range(of: "<TYPE>INFORMATION TABLE", options: [.caseInsensitive])
            ?? text.range(of: "<TYPE>INFORMATION TABLE\r", options: [.regularExpression, .caseInsensitive])
        guard let typeRange else { return nil }

        let afterType = text[typeRange.upperBound...]

        guard let textOpen = afterType.range(of: "<TEXT>", options: [.caseInsensitive]) else { return nil }
        let afterTextOpen = afterType[textOpen.upperBound...]

        guard let textClose = afterTextOpen.range(of: "</TEXT>", options: [.caseInsensitive]) else { return nil }
        let payload = afterTextOpen[..<textClose.lowerBound]

        // Trim surrounding whitespace; keep bytes.
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Data(trimmed.utf8)
    }
}

