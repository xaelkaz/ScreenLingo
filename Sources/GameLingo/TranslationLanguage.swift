import Foundation
import Translation

struct TranslationLanguage: Hashable, Sendable {
    let identifier: String

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: identifier)
    }

    var displayName: String {
        Locale(identifier: "en").localizedString(forIdentifier: identifier)
            ?? identifier
    }

    var uppercaseDisplayName: String {
        displayName.uppercased(with: Locale(identifier: "en"))
    }
}

struct TranslationLanguageCatalog: Sendable {
    let sourceLanguages: [TranslationLanguage]
    let targetLanguages: [TranslationLanguage]

    private static let fallbackIdentifiers = [
        "ar", "zh-Hans", "zh-Hant", "nl", "en", "fr", "de", "id", "it",
        "ja", "ko", "pl", "pt-BR", "ru", "es", "th", "tr", "vi"
    ]
    private static let excludedLanguageCodes: Set<String> = ["uk"]

    static func load() async -> TranslationLanguageCatalog {
        let availableLanguages = await LanguageAvailability().supportedLanguages
        let targetLanguages: [TranslationLanguage]
        if availableLanguages.isEmpty {
            targetLanguages = sortedUniqueLanguages(
                fallbackIdentifiers.map(TranslationLanguage.init(identifier:))
            )
        } else {
            targetLanguages = uniqueLanguages(from: availableLanguages)
        }
        let sourceLanguages = targetLanguages.filter {
            TextRecognizer.recognitionLanguageIdentifier(for: $0.identifier) != nil
        }

        return TranslationLanguageCatalog(
            sourceLanguages: sourceLanguages,
            targetLanguages: targetLanguages
        )
    }

    private static func uniqueLanguages(
        from languages: [Locale.Language]
    ) -> [TranslationLanguage] {
        sortedUniqueLanguages(
            languages
            .map { TranslationLanguage(identifier: identifier(for: $0)) }
        )
    }

    private static func sortedUniqueLanguages(
        _ languages: [TranslationLanguage]
    ) -> [TranslationLanguage] {
        var seen = Set<String>()
        return languages
            .filter { language in
                guard let code = language.localeLanguage.languageCode?.identifier else {
                    return false
                }
                return !excludedLanguageCodes.contains(code)
            }
            .filter { seen.insert($0.identifier).inserted }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private static func identifier(for language: Locale.Language) -> String {
        let components = [
            language.languageCode?.identifier,
            language.script?.identifier,
            language.region?.identifier
        ].compactMap { $0 }

        return components.joined(separator: "-")
    }
}
