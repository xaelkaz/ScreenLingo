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

    func makeLiveCapture(appKitRegion: CGRect) async throws -> LiveRegionCapture {
        guard #available(macOS 15.2, *) else {
            throw GameLingoError.unsupportedSystem
        }
        return try await makeLiveCaptureAvailable(appKitRegion: appKitRegion)
    }

    @available(macOS 15.2, *)
    private func makeLiveCaptureAvailable(appKitRegion: CGRect) async throws -> LiveRegionCapture {
        guard appKitRegion.width > 0, appKitRegion.height > 0 else {
            throw GameLingoError.invalidRegion
        }

        let screenDescriptor = await MainActor.run { () -> (CGDirectDisplayID, CGFloat)? in
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(appKitRegion) }),
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
            return (CGDirectDisplayID(number.uint32Value), primaryMaxY)
        }

        guard let (displayID, primaryMaxY) = screenDescriptor else {
            throw GameLingoError.liveRegionMustFitSingleDisplay
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw GameLingoError.liveSetupFailed
            }

            let ownApplications = content.applications.filter { application in
                application.processID == ProcessInfo.processInfo.processIdentifier
            }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: []
            )

            let globalCaptureRect = ScreenCoordinateConverter.screenCaptureRect(
                from: appKitRegion,
                primaryScreenMaxY: primaryMaxY
            )
            let localRect = globalCaptureRect.offsetBy(
                dx: -display.frame.minX,
                dy: -display.frame.minY
            )
            guard localRect.minX >= 0,
                  localRect.minY >= 0,
                  localRect.maxX <= display.frame.width,
                  localRect.maxY <= display.frame.height else {
                throw GameLingoError.liveRegionMustFitSingleDisplay
            }

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = localRect
            configuration.width = max(1, Int(localRect.width * CGFloat(filter.pointPixelScale)))
            configuration.height = max(1, Int(localRect.height * CGFloat(filter.pointPixelScale)))
            configuration.showsCursor = false
            configuration.capturesAudio = false

            return LiveRegionCapture(filter: filter, configuration: configuration)
        } catch let error as GameLingoError {
            throw error
        } catch {
            throw GameLingoError.captureFailed(error)
        }
    }
}

final class LiveRegionCapture {
    private let filter: SCContentFilter
    private let configuration: SCStreamConfiguration

    init(filter: SCContentFilter, configuration: SCStreamConfiguration) {
        self.filter = filter
        self.configuration = configuration
    }

    func capture() async throws -> CGImage {
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw GameLingoError.captureFailed(error)
        }
    }
}
