import AppKit
import Carbon
import CoreGraphics
import GameLingoCore

@MainActor
final class AppController: NSObject {
    private enum SelectionPurpose {
        case singleTranslation
        case liveSubtitles
    }

    private let statusItem: NSStatusItem
    private let selector = RegionSelectionCoordinator()
    private let captureService = ScreenCaptureService()
    private let textRecognizer = TextRecognizer()
    private let panelController = TranslationPanelController()
    private let preferences = GameLingoPreferences()

    private var settingsController: SettingsWindowController?
    private var captureHotKey: GlobalHotKey?
    private var repeatHotKey: GlobalHotKey?
    private var liveHotKey: GlobalHotKey?
    private var activeTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var processingID: UUID?
    private var liveSessionID: UUID?
    private var isSelecting = false
    private var lastRegion: CGRect?

    private var translateItem: NSMenuItem!
    private var repeatItem: NSMenuItem!
    private var liveItem: NSMenuItem!

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        lastRegion = validatedLastRegion(preferences.lastRegion)
        configureStatusItem()
        registerCaptureHotKey(presentError: true)
        registerFixedHotKeys()
        settingsController = SettingsWindowController(
            preferences: preferences,
            onShortcutChange: { [weak self] shortcut in
                self?.applyCaptureShortcut(shortcut) ?? false
            },
            onRecordingStateChange: { [weak self] isRecording in
                self?.setShortcutsSuspended(isRecording)
            },
            onLanguageChange: { [weak self] in
                self?.languageSettingsChanged()
            }
        )
    }

    func stop() {
        cancelSingleProcessing()
        stopLiveMode(closePanel: true)
        captureHotKey = nil
        repeatHotKey = nil
        liveHotKey = nil
        selector.cancel()
        settingsController?.close()
        panelController.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "GameLingo")
            button.toolTip = "GameLingo — translate text on screen"
        }

        let menu = NSMenu()

        translateItem = NSMenuItem(title: "", action: #selector(translateRegionFromMenu), keyEquivalent: "")
        translateItem.target = self
        updateCaptureMenuTitle()
        menu.addItem(translateItem)

        repeatItem = NSMenuItem(
            title: "Repeat Last Region",
            action: #selector(repeatLastRegionFromMenu),
            keyEquivalent: "r"
        )
        repeatItem.keyEquivalentModifierMask = [.command, .option]
        repeatItem.target = self
        repeatItem.isEnabled = lastRegion != nil
        menu.addItem(repeatItem)

        liveItem = NSMenuItem(
            title: "Start Live Subtitles",
            action: #selector(toggleLiveModeFromMenu),
            keyEquivalent: "s"
        )
        liveItem.keyEquivalentModifierMask = [.command, .option]
        liveItem.target = self
        menu.addItem(liveItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About GameLingo", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit GameLingo", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func registerCaptureHotKey(presentError: Bool) {
        let shortcut = preferences.captureShortcut
        do {
            captureHotKey = try GlobalHotKey(
                identifier: 1,
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers
            ) { [weak self] in
                self?.startSingleTranslationSelection()
            }
        } catch {
            captureHotKey = nil
            if presentError {
                showError(
                    title: "The shortcut could not be registered",
                    message: "\(shortcut.displayName) may already be used by another app. You can change it in Settings."
                )
            }
        }
    }

    private func registerFixedHotKeys() {
        if repeatHotKey == nil {
            let repeatShortcut = HotKeyShortcut.repeatRegion
            repeatHotKey = try? GlobalHotKey(
                identifier: 2,
                keyCode: repeatShortcut.keyCode,
                modifiers: repeatShortcut.modifiers
            ) { [weak self] in
                self?.repeatLastRegion()
            }
        }

        if liveHotKey == nil {
            let liveShortcut = HotKeyShortcut.toggleLive
            liveHotKey = try? GlobalHotKey(
                identifier: 3,
                keyCode: liveShortcut.keyCode,
                modifiers: liveShortcut.modifiers
            ) { [weak self] in
                self?.toggleLiveMode()
            }
        }
    }

    private func setShortcutsSuspended(_ suspended: Bool) {
        if suspended {
            captureHotKey = nil
            repeatHotKey = nil
            liveHotKey = nil
            return
        }

        if captureHotKey == nil {
            registerCaptureHotKey(presentError: false)
        }
        if repeatHotKey == nil || liveHotKey == nil {
            registerFixedHotKeys()
        }
    }

    private func applyCaptureShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        let previous = preferences.captureShortcut
        guard shortcut != previous else { return true }

        captureHotKey = nil
        do {
            let newHotKey = try GlobalHotKey(
                identifier: 1,
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers
            ) { [weak self] in
                self?.startSingleTranslationSelection()
            }
            captureHotKey = newHotKey
            preferences.captureShortcut = shortcut
            updateCaptureMenuTitle()
            return true
        } catch {
            preferences.captureShortcut = previous
            registerCaptureHotKey(presentError: false)
            return false
        }
    }

    private func updateCaptureMenuTitle() {
        translateItem?.title = "Translate Region (\(preferences.captureShortcut.displayName))"
    }

    @objc private func translateRegionFromMenu() {
        startSingleTranslationSelection()
    }

    @objc private func repeatLastRegionFromMenu() {
        repeatLastRegion()
    }

    @objc private func toggleLiveModeFromMenu() {
        toggleLiveMode()
    }

    private func startSingleTranslationSelection() {
        beginSelection(for: .singleTranslation)
    }

    private func toggleLiveMode() {
        if liveTask != nil {
            stopLiveMode(closePanel: true)
        } else {
            beginSelection(for: .liveSubtitles)
        }
    }

    private func beginSelection(for purpose: SelectionPurpose) {
        guard !isSelecting else { return }

        guard captureService.ensurePermission() else {
            showCapturePermissionAlert()
            return
        }

        stopLiveMode(closePanel: true)
        cancelSingleProcessing()
        panelController.close()
        isSelecting = true

        selector.begin { [weak self] region in
            guard let self else { return }
            self.isSelecting = false
            self.remember(region: region)

            switch purpose {
            case .singleTranslation:
                self.processSingleTranslation(region: region)
            case .liveSubtitles:
                self.startLiveMode(region: region)
            }
        } onCancel: { [weak self] in
            self?.isSelecting = false
        }
    }

    private func repeatLastRegion() {
        guard !isSelecting else { return }
        guard captureService.ensurePermission() else {
            showCapturePermissionAlert()
            return
        }
        guard let region = validatedLastRegion(lastRegion) else {
            lastRegion = nil
            preferences.lastRegion = nil
            repeatItem.isEnabled = false
            showError(
                title: "There is no saved region yet",
                message: "Translate a region once, then repeat it with ⌥⌘R."
            )
            return
        }

        stopLiveMode(closePanel: true)
        cancelSingleProcessing()
        panelController.close()
        processSingleTranslation(region: region)
    }

    private func remember(region: CGRect) {
        lastRegion = region
        preferences.lastRegion = region
        repeatItem.isEnabled = true
    }

    private func validatedLastRegion(_ region: CGRect?) -> CGRect? {
        guard let region,
              NSScreen.screens.contains(where: { $0.frame.contains(region) }) else {
            return nil
        }
        return region
    }

    private func processSingleTranslation(region: CGRect) {
        let requestID = UUID()
        let sourceLanguage = TranslationLanguage(identifier: preferences.sourceLanguageIdentifier)
        let targetLanguage = TranslationLanguage(identifier: preferences.targetLanguageIdentifier)
        processingID = requestID
        setBusy(true)

        activeTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .milliseconds(120))
                try Task.checkCancellation()

                let image = try await captureService.capture(appKitRegion: region)
                try Task.checkCancellation()

                let recognizedText = try await textRecognizer.recognizeText(
                    in: image,
                    sourceLanguageIdentifier: sourceLanguage.identifier
                )
                try Task.checkCancellation()

                panelController.show(
                    sourceText: recognizedText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    near: region,
                    showsOriginalText: preferences.showsOriginalText,
                    isLive: false,
                    shortcutDisplayName: preferences.captureShortcut.displayName
                )
            } catch is CancellationError {
                // A new operation replaced this request.
            } catch let error as GameLingoError {
                showError(title: error.title, message: error.localizedDescription)
            } catch {
                showError(title: "This region could not be translated", message: error.localizedDescription)
            }

            if processingID == requestID {
                processingID = nil
                activeTask = nil
                setBusy(false)
            }
        }
    }

    private func cancelSingleProcessing() {
        activeTask?.cancel()
        activeTask = nil
        processingID = nil
        setBusy(false)
    }

    private func startLiveMode(region: CGRect) {
        let sessionID = UUID()
        let sourceLanguage = TranslationLanguage(identifier: preferences.sourceLanguageIdentifier)
        let targetLanguage = TranslationLanguage(identifier: preferences.targetLanguageIdentifier)
        liveSessionID = sessionID
        setLiveUI(active: true)

        liveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(120))
                let liveCapture = try await captureService.makeLiveCapture(appKitRegion: region)
                var lastFingerprint: UInt64?
                var lastNormalizedText: String?

                while !Task.isCancelled {
                    let image = try await liveCapture.capture()
                    try Task.checkCancellation()

                    if let fingerprint = FrameFingerprint.make(from: image) {
                        if let previous = lastFingerprint, previous == fingerprint {
                            try await sleepForLiveInterval()
                            continue
                        }
                        lastFingerprint = fingerprint
                    }

                    do {
                        let recognizedText = try await textRecognizer.recognizeText(
                            in: image,
                            sourceLanguageIdentifier: sourceLanguage.identifier
                        )
                        let normalized = LiveTextNormalizer.normalize(recognizedText)
                        if !normalized.isEmpty, normalized != lastNormalizedText {
                            lastNormalizedText = normalized
                            panelController.show(
                                sourceText: recognizedText,
                                sourceLanguage: sourceLanguage,
                                targetLanguage: targetLanguage,
                                near: region,
                                showsOriginalText: preferences.showsOriginalText,
                                isLive: true,
                                shortcutDisplayName: preferences.captureShortcut.displayName
                            )
                        }
                    } catch GameLingoError.noTextFound {
                        lastNormalizedText = nil
                        panelController.close()
                    }

                    try await sleepForLiveInterval()
                }
            } catch is CancellationError {
                // Expected when the user stops live subtitles.
            } catch let error as GameLingoError {
                showError(title: error.title, message: error.localizedDescription)
            } catch {
                showError(title: "Live subtitles stopped", message: error.localizedDescription)
            }

            if liveSessionID == sessionID {
                liveSessionID = nil
                liveTask = nil
                setLiveUI(active: false)
            }
        }
    }

    private func sleepForLiveInterval() async throws {
        let nanoseconds = UInt64(preferences.liveInterval * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    private func stopLiveMode(closePanel: Bool) {
        liveSessionID = nil
        liveTask?.cancel()
        liveTask = nil
        if closePanel {
            panelController.close()
        }
        setLiveUI(active: false)
    }

    private func setBusy(_ busy: Bool) {
        guard liveTask == nil else { return }
        statusItem.button?.image = NSImage(
            systemSymbolName: busy ? "ellipsis.bubble" : "character.bubble",
            accessibilityDescription: busy ? "Processing" : "GameLingo"
        )
    }

    private func setLiveUI(active: Bool) {
        liveItem?.title = active ? "Stop Live Subtitles" : "Start Live Subtitles"
        statusItem.button?.image = NSImage(
            systemSymbolName: active ? "captions.bubble.fill" : "character.bubble",
            accessibilityDescription: active ? "Live subtitles active" : "GameLingo"
        )
        statusItem.button?.toolTip = active
            ? "GameLingo — live subtitles active"
            : "GameLingo — translate text on screen"
    }

    private func showCapturePermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "GameLingo needs access to your screen"
        alert.informativeText = "Allow GameLingo in System Settings → Privacy & Security → Screen & System Audio Recording. You may need to quit and reopen the app once."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

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
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func showSettings() {
        settingsController?.show()
    }

    private func languageSettingsChanged() {
        cancelSingleProcessing()
        stopLiveMode(closePanel: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "GameLingo"
        let source = TranslationLanguage(identifier: preferences.sourceLanguageIdentifier).displayName
        let target = TranslationLanguage(identifier: preferences.targetLanguageIdentifier).displayName
        alert.informativeText = "Translate game text from \(source) to \(target) and create live subtitles.\n\nTranslate: \(preferences.captureShortcut.displayName)\nRepeat region: ⌥⌘R\nLive subtitles: ⌥⌘S\n\nAll processing happens on your Mac."
        alert.addButton(withTitle: "Done")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
