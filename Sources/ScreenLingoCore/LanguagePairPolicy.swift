public struct LanguagePair: Equatable, Sendable {
    public let sourceIdentifier: String
    public let targetIdentifier: String

    public init(sourceIdentifier: String, targetIdentifier: String) {
        self.sourceIdentifier = sourceIdentifier
        self.targetIdentifier = targetIdentifier
    }
}

public enum LanguagePairPolicy {
    public static let automaticSourceIdentifier = "auto"

    public static func swappedPair(
        sourceIdentifier: String,
        targetIdentifier: String,
        availableSourceIdentifiers: Set<String>
    ) -> LanguagePair? {
        guard sourceIdentifier != automaticSourceIdentifier,
              sourceIdentifier != targetIdentifier,
              availableSourceIdentifiers.contains(targetIdentifier) else {
            return nil
        }

        return LanguagePair(
            sourceIdentifier: targetIdentifier,
            targetIdentifier: sourceIdentifier
        )
    }
}
