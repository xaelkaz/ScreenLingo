import CoreGraphics
import Darwin
import ScreenLingoCore

private var failures = 0

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("✓ \(name)")
    } else {
        failures += 1
        print("✗ \(name)")
    }
}

let appKitRect = CGRect(x: 100, y: 150, width: 300, height: 200)
let captureRect = ScreenCoordinateConverter.screenCaptureRect(
    from: appKitRect,
    primaryScreenMaxY: 900
)
check(
    captureRect == CGRect(x: 100, y: 550, width: 300, height: 200),
    "converts AppKit coordinates to ScreenCaptureKit"
)

let regionAbovePrimary = CGRect(x: 20, y: 950, width: 200, height: 100)
let captureAbovePrimary = ScreenCoordinateConverter.screenCaptureRect(
    from: regionAbovePrimary,
    primaryScreenMaxY: 900
)
check(
    captureAbovePrimary == CGRect(x: 20, y: -150, width: 200, height: 100),
    "converts coordinates from a display above the primary display"
)

let verticalLines = [
    RecognizedLine(text: "third", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1)),
    RecognizedLine(text: "first", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.4, height: 0.1)),
    RecognizedLine(text: "second", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.4, height: 0.1))
]
check(
    RecognizedLineSorter.readingOrder(verticalLines).map(\.text) == ["first", "second", "third"],
    "orders OCR lines from top to bottom"
)

let horizontalWords = [
    RecognizedLine(text: "world", boundingBox: CGRect(x: 0.55, y: 0.5, width: 0.2, height: 0.1)),
    RecognizedLine(text: "hello", boundingBox: CGRect(x: 0.1, y: 0.51, width: 0.2, height: 0.1))
]
check(
    RecognizedLineSorter.readingOrder(horizontalWords).map(\.text) == ["hello", "world"],
    "orders OCR words from left to right"
)

check(
    LiveTextNormalizer.normalize("  The   SAME\nDialogue  ") == "the same dialogue",
    "normalizes text to avoid duplicate translations"
)

let ocrLanguageIdentifiers = ["en-US", "pt-BR", "zh-Hans", "zh-Hant"]
check(
    LanguageIdentifierMatcher.bestMatch(
        for: "zh-Hant",
        among: ocrLanguageIdentifiers
    ) == "zh-Hant",
    "preserves the requested writing system when matching OCR languages"
)
check(
    LanguageIdentifierMatcher.bestMatch(
        for: "pt-PT",
        among: ocrLanguageIdentifiers
    ) == "pt-BR",
    "falls back to another region of the same OCR language"
)
check(
    LanguageIdentifierMatcher.bestMatch(
        for: "el",
        among: ocrLanguageIdentifiers
    ) == nil,
    "rejects source languages that Vision OCR cannot recognize"
)

if failures > 0 {
    print("\n\(failures) check(s) failed.")
    exit(EXIT_FAILURE)
}

print("\n8 checks passed.")
