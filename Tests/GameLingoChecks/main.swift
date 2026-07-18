import CoreGraphics
import Darwin
import GameLingoCore

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
    "convierte coordenadas AppKit a ScreenCaptureKit"
)

let regionAbovePrimary = CGRect(x: 20, y: 950, width: 200, height: 100)
let captureAbovePrimary = ScreenCoordinateConverter.screenCaptureRect(
    from: regionAbovePrimary,
    primaryScreenMaxY: 900
)
check(
    captureAbovePrimary == CGRect(x: 20, y: -150, width: 200, height: 100),
    "convierte coordenadas de un monitor sobre el principal"
)

let verticalLines = [
    RecognizedLine(text: "third", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1)),
    RecognizedLine(text: "first", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.4, height: 0.1)),
    RecognizedLine(text: "second", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.4, height: 0.1))
]
check(
    RecognizedLineSorter.readingOrder(verticalLines).map(\.text) == ["first", "second", "third"],
    "ordena líneas OCR de arriba hacia abajo"
)

let horizontalWords = [
    RecognizedLine(text: "world", boundingBox: CGRect(x: 0.55, y: 0.5, width: 0.2, height: 0.1)),
    RecognizedLine(text: "hello", boundingBox: CGRect(x: 0.1, y: 0.51, width: 0.2, height: 0.1))
]
check(
    RecognizedLineSorter.readingOrder(horizontalWords).map(\.text) == ["hello", "world"],
    "ordena palabras OCR de izquierda a derecha"
)

check(
    LiveTextNormalizer.normalize("  The   SAME\nDialogue  ") == "the same dialogue",
    "normaliza texto para evitar traducciones duplicadas"
)

if failures > 0 {
    print("\n\(failures) comprobación(es) fallaron.")
    exit(EXIT_FAILURE)
}

print("\n5 comprobaciones pasaron.")
