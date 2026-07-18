import Foundation

enum GameLingoError: LocalizedError {
    case unsupportedSystem
    case invalidRegion
    case captureFailed(Error)
    case ocrFailed(Error)
    case noTextFound
    case liveRegionMustFitSingleDisplay
    case liveSetupFailed

    var title: String {
        switch self {
        case .unsupportedSystem:
            return "Esta versión de macOS no es compatible"
        case .invalidRegion:
            return "La selección no es válida"
        case .captureFailed:
            return "No se pudo capturar la pantalla"
        case .ocrFailed:
            return "No se pudo leer el texto"
        case .noTextFound:
            return "No encontré texto en inglés"
        case .liveRegionMustFitSingleDisplay:
            return "La región automática cruza dos pantallas"
        case .liveSetupFailed:
            return "No se pudo iniciar el modo automático"
        }
    }

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "GameLingo necesita macOS 15.2 o una versión posterior."
        case .invalidRegion:
            return "Selecciona un área de al menos 8 × 8 puntos."
        case .captureFailed(let error):
            return "Comprueba el permiso de Grabación de pantalla e inténtalo de nuevo. Detalle: \(error.localizedDescription)"
        case .ocrFailed(let error):
            return "Vision no pudo analizar la imagen. Detalle: \(error.localizedDescription)"
        case .noTextFound:
            return "Prueba seleccionando un área más ajustada al diálogo o aumentando el tamaño del texto del juego."
        case .liveRegionMustFitSingleDisplay:
            return "Selecciona una zona de diálogo que esté completamente dentro de un solo monitor."
        case .liveSetupFailed:
            return "GameLingo no encontró la pantalla seleccionada. Intenta seleccionar la región nuevamente."
        }
    }
}
