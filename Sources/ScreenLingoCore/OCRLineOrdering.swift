import CoreGraphics

public struct RecognizedLine: Equatable {
    public let text: String
    public let boundingBox: CGRect

    public init(text: String, boundingBox: CGRect) {
        self.text = text
        self.boundingBox = boundingBox
    }
}

public enum RecognizedLineSorter {
    public static func readingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { lhs, rhs in
            let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            let sameVisualLineThreshold = max(lhs.boundingBox.height, rhs.boundingBox.height) * 0.45

            if verticalDistance <= sameVisualLineThreshold {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
    }
}
