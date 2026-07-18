import CoreGraphics

public enum ScreenCoordinateConverter {
    public static func screenCaptureRect(from appKitRect: CGRect, primaryScreenMaxY: CGFloat) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: primaryScreenMaxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}
