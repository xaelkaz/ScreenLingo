import Foundation

enum GameLingoError: LocalizedError {
    case unsupportedSystem
    case invalidRegion
    case captureFailed(Error)
    case ocrFailed(Error)
    case noTextFound
    case unsupportedOCRLanguage(String)
    case liveRegionMustFitSingleDisplay
    case liveSetupFailed

    var title: String {
        switch self {
        case .unsupportedSystem:
            return "This version of macOS is not supported"
        case .invalidRegion:
            return "The selected region is not valid"
        case .captureFailed:
            return "The screen could not be captured"
        case .ocrFailed:
            return "The text could not be read"
        case .noTextFound:
            return "No text was found"
        case .unsupportedOCRLanguage(let language):
            return "OCR is not available for \(language)"
        case .liveRegionMustFitSingleDisplay:
            return "The live region crosses multiple displays"
        case .liveSetupFailed:
            return "Live subtitles could not be started"
        }
    }

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "GameLingo requires macOS 15.2 or later."
        case .invalidRegion:
            return "Select an area of at least 8 × 8 points."
        case .captureFailed(let error):
            return "Check the Screen Recording permission and try again. Details: \(error.localizedDescription)"
        case .ocrFailed(let error):
            return "Vision could not analyze the image. Details: \(error.localizedDescription)"
        case .noTextFound:
            return "Try selecting a tighter area around the dialogue or increasing the game's text size."
        case .unsupportedOCRLanguage(let language):
            return "Vision cannot recognize \(language) on this Mac. Choose another source language in Settings."
        case .liveRegionMustFitSingleDisplay:
            return "Select a dialogue area that is fully contained within a single display."
        case .liveSetupFailed:
            return "GameLingo could not find the selected display. Select the region again."
        }
    }
}
