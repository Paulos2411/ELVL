import Foundation

public enum TextChunker {
    public static func chunk(text: String, maxCharacters: Int) -> [String] {
        precondition(maxCharacters > 0)

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        var result: [String] = []
        result.reserveCapacity(max(1, cleaned.count / maxCharacters))

        var start = cleaned.startIndex
        while start < cleaned.endIndex {
            var end = cleaned.index(start, offsetBy: maxCharacters, limitedBy: cleaned.endIndex) ?? cleaned.endIndex

            if end < cleaned.endIndex {
                let slice = cleaned[start..<end]
                if let boundary = slice.lastIndex(where: { $0 == "\n" || $0 == "." || $0 == " " }), boundary > start {
                    end = boundary
                }
            }

            if end == start {
                end = cleaned.index(after: start)
            }

            let chunk = String(cleaned[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                result.append(chunk)
            }

            start = end
            while start < cleaned.endIndex, (cleaned[start].isWhitespace || cleaned[start].isNewline) {
                start = cleaned.index(after: start)
            }
        }

        return result
    }
}

