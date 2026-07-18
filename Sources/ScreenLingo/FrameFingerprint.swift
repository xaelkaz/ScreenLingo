import CoreGraphics

enum FrameFingerprint {
    static func make(from image: CGImage) -> UInt64? {
        let width = 32
        let height = 18
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let created = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard created else { return nil }

        // FNV-1a over a small grayscale preview. Exact equality skips static
        // frames without risking the loss of subtle dialogue changes.
        var fingerprint: UInt64 = 14_695_981_039_346_656_037
        for pixel in pixels {
            fingerprint ^= UInt64(pixel)
            fingerprint &*= 1_099_511_628_211
        }
        return fingerprint
    }
}
