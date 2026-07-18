import CoreGraphics
import Foundation
import GameLingoCore
import Vision

final class TextRecognizer {
    private static let supportedRecognitionLanguages: [String] = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
    }()

    static func recognitionLanguageIdentifier(for translationIdentifier: String) -> String? {
        LanguageIdentifierMatcher.bestMatch(
            for: translationIdentifier,
            among: supportedRecognitionLanguages
        )
    }

    func recognizeText(
        in image: CGImage,
        sourceLanguageIdentifier: String
    ) async throws -> String {
        guard let recognitionLanguage = Self.recognitionLanguageIdentifier(
            for: sourceLanguageIdentifier
        ) else {
            throw GameLingoError.unsupportedOCRLanguage(
                TranslationLanguage(identifier: sourceLanguageIdentifier).displayName
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: GameLingoError.ocrFailed(error))
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { observation -> RecognizedLine? in
                        guard let candidate = observation.topCandidates(1).first,
                              candidate.confidence >= 0.15 else {
                            return nil
                        }

                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return nil }
                        return RecognizedLine(text: text, boundingBox: observation.boundingBox)
                    }

                    let text = RecognizedLineSorter.readingOrder(lines)
                        .map(\.text)
                        .joined(separator: "\n")

                    guard !text.isEmpty else {
                        continuation.resume(throwing: GameLingoError.noTextFound)
                        return
                    }
                    continuation.resume(returning: text)
                }

                request.recognitionLevel = .accurate
                request.recognitionLanguages = [recognitionLanguage]
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.012

                do {
                    let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: GameLingoError.ocrFailed(error))
                }
            }
        }
    }
}
