import Foundation

public enum LanguageIdentifierMatcher {
    public static func bestMatch(
        for requestedIdentifier: String,
        among candidateIdentifiers: [String]
    ) -> String? {
        let requested = Locale.Language(identifier: requestedIdentifier)
        guard let languageCode = requested.languageCode?.identifier else { return nil }

        let candidates = candidateIdentifiers.filter {
            Locale.Language(identifier: $0).languageCode?.identifier == languageCode
        }
        guard !candidates.isEmpty else { return nil }

        if let requestedScript = requested.script?.identifier,
           let scriptMatch = candidates.first(where: {
               Locale.Language(identifier: $0).script?.identifier == requestedScript
           }) {
            return scriptMatch
        }

        if let requestedRegion = requested.region?.identifier,
           let regionMatch = candidates.first(where: {
               Locale.Language(identifier: $0).region?.identifier == requestedRegion
           }) {
            return regionMatch
        }

        return candidates[0]
    }
}
