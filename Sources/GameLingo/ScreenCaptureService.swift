import AppKit
import CoreGraphics
import GameLingoCore
import ScreenCaptureKit

final class ScreenCaptureService {
    func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }

    @available(macOS 15.2, *)
    private func captureAvailable(appKitRegion: CGRect) async throws -> CGImage {
        guard appKitRegion.width > 0, appKitRegion.height > 0 else {
            throw GameLingoError.invalidRegion
        }

        let primaryScreenMaxY = await MainActor.run {
            NSScreen.screens.first?.frame.maxY ?? 0
        }
        let captureRect = ScreenCoordinateConverter.screenCaptureRect(
            from: appKitRegion,
            primaryScreenMaxY: primaryScreenMaxY
        )

        do {
            return try await SCScreenshotManager.captureImage(in: captureRect)
        } catch {
            throw GameLingoError.captureFailed(error)
        }
    }

    func capture(appKitRegion: CGRect) async throws -> CGImage {
        guard #available(macOS 15.2, *) else {
            throw GameLingoError.unsupportedSystem
        }
        return try await captureAvailable(appKitRegion: appKitRegion)
    }
}
