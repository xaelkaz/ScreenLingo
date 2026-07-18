import AppKit
import Carbon
import CoreGraphics

@MainActor
final class AppController: NSObject {
    private let statusItem: NSStatusItem
    private let selector = RegionSelectionCoordinator()
    private let captureService = ScreenCaptureService()
    private let textRecognizer = TextRecognizer()
    private let panelController = TranslationPanelController()
    private var hotKey: GlobalHotKey?
    private var activeTask: Task<Void, Never>?
    private var processingID: UUID?
    private var isSelecting = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()

        do {
            hotKey = try GlobalHotKey(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
                self?.startTranslation()
            }
        } catch {
            showError(
                title: "No se pudo registrar el atajo",
                message: "⌥⌘T ya puede estar siendo utilizado por otra aplicación. Todavía puedes iniciar la captura desde el icono de GameLingo."
            )
        }
    }

    func stop() {
        activeTask?.cancel()
        processingID = nil
        hotKey = nil
        selector.cancel()
        panelController.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "GameLingo")
            button.toolTip = "GameLingo — traducir texto de la pantalla"
        }

        let menu = NSMenu()
        let translateItem = NSMenuItem(
            title: "Traducir región",
            action: #selector(translateRegionFromMenu),
            keyEquivalent: "t"
        )
        translateItem.keyEquivalentModifierMask = [.command, .option]
        translateItem.target = self
        menu.addItem(translateItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "Acerca de GameLingo", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Salir de GameLingo", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func translateRegionFromMenu() {
        startTranslation()
    }

    private func startTranslation() {
        guard !isSelecting else { return }

        guard captureService.ensurePermission() else {
            showCapturePermissionAlert()
            return
        }

        activeTask?.cancel()
        processingID = nil
        setBusy(false)
        panelController.close()
        isSelecting = true

        selector.begin { [weak self] region in
            guard let self else { return }
            self.isSelecting = false
            self.process(region: region)
        } onCancel: { [weak self] in
            self?.isSelecting = false
        }
    }

    private func process(region: CGRect) {
        let requestID = UUID()
        processingID = requestID
        setBusy(true)

        activeTask = Task { [weak self] in
            guard let self else { return }

            do {
                // Give the selection overlay a moment to leave the composited screen.
                try await Task.sleep(for: .milliseconds(120))
                try Task.checkCancellation()

                let image = try await captureService.capture(appKitRegion: region)
                try Task.checkCancellation()

                let recognizedText = try await textRecognizer.recognizeText(in: image)
                try Task.checkCancellation()

                panelController.show(sourceText: recognizedText, near: region)
            } catch is CancellationError {
                // A new translation replaced this request.
            } catch let error as GameLingoError {
                showError(title: error.title, message: error.localizedDescription)
            } catch {
                showError(
                    title: "No se pudo traducir esta región",
                    message: error.localizedDescription
                )
            }

            if processingID == requestID {
                processingID = nil
                setBusy(false)
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        statusItem.button?.image = NSImage(
            systemSymbolName: busy ? "ellipsis.bubble" : "character.bubble",
            accessibilityDescription: busy ? "Procesando" : "GameLingo"
        )
    }

    private func showCapturePermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "GameLingo necesita ver la pantalla"
        alert.informativeText = "Autoriza GameLingo en Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla. Es posible que debas cerrar y abrir la aplicación una vez."
        alert.addButton(withTitle: "Abrir ajustes")
        alert.addButton(withTitle: "Ahora no")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Aceptar")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "GameLingo"
        alert.informativeText = "Selecciona texto en inglés en cualquier juego y obtén su traducción al español.\n\nAtajo global: ⌥⌘T\nTodo el procesamiento se realiza en tu Mac."
        alert.addButton(withTitle: "Listo")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
