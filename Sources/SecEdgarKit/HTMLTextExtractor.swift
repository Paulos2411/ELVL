import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum HTMLTextExtractor {
    public enum HTMLTextError: Error {
        case notHTML
    }

    public static func extractText(fromHTMLData data: Data) throws -> String {
        #if canImport(UIKit) || canImport(AppKit)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let attributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
        return normalizeWhitespace(attributed.string)
        #else
        throw HTMLTextError.notHTML
        #endif
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Keep paragraph breaks but collapse excessive empties.
        var result: [String] = []
        result.reserveCapacity(lines.count)
        var emptyCount = 0
        for line in lines {
            if line.isEmpty {
                emptyCount += 1
                if emptyCount <= 2 {
                    result.append("")
                }
            } else {
                emptyCount = 0
                result.append(line)
            }
        }
        return result.joined(separator: "\n")
    }
}
