import CoreGraphics
import Foundation
import GameLingoCore
import Vision

final class TextRecognizer {
    func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
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
                request.recognitionLanguages = ["en-US"]
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
