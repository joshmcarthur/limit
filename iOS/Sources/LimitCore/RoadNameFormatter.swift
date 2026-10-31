import Foundation

/// The register stores names in capitals (`GLOUCESTER STREET`, `WELLINGTON CITY UTA`).
public enum RoadNameFormatter {
    private static let keepUppercase: Set<String> = ["SH", "NZ"]

    public static func display(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        // UTA = urban traffic area; the suffix is register jargon, not part of the place name.
        if text.uppercased().hasSuffix(" UTA") { text = String(text.dropLast(4)) }
        if text.uppercased() == "UTA" { return nil }
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map { word -> String in
            let upper = word.uppercased()
            if keepUppercase.contains(upper) || upper.hasPrefix("SH") && upper.dropFirst(2).allSatisfy(\.isNumber) {
                return upper
            }
            return capitalise(String(word))
        }
        let result = words.joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    /// Capitalises the first letter and any letter after `-` or `(`.
    private static func capitalise(_ word: String) -> String {
        var out = ""
        var capitaliseNext = true
        for character in word {
            out += capitaliseNext ? character.uppercased() : character.lowercased()
            capitaliseNext = character == "-" || character == "("
        }
        return out
    }
}
