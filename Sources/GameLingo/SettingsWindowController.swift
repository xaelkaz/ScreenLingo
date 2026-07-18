import AppKit
import Carbon

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: GameLingoPreferences
    private let onShortcutChange: (HotKeyShortcut) -> Bool
    private let onRecordingStateChange: (Bool) -> Void
    private let onLanguageChange: () -> Void
    private var window: NSWindow?
    private var sourceLanguagePopup: NSPopUpButton?
    private var targetLanguagePopup: NSPopUpButton?
    private var shortcutButton: NSButton?
    private var intervalPopup: NSPopUpButton?
    private var originalTextCheckbox: NSButton?
    private var keyMonitor: Any?
    private var languageTask: Task<Void, Never>?
    private var isRecordingShortcut = false

    init(
        preferences: GameLingoPreferences,
        onShortcutChange: @escaping (HotKeyShortcut) -> Bool,
        onRecordingStateChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.onShortcutChange = onShortcutChange
        self.onRecordingStateChange = onRecordingStateChange
        self.onLanguageChange = onLanguageChange
    }

    func show() {
        if window == nil {
            buildWindow()
        }
        refreshControls()
        loadLanguages()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        stopRecordingShortcut()
        languageTask?.cancel()
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopRecordingShortcut()
        languageTask?.cancel()
    }

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "GameLingo Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window

        let effect = NSVisualEffectView()
        effect.material = .sidebar
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = effect

        let title = label("Settings", size: 22, weight: .bold)
        let subtitle = label(
            "Choose your languages and customize how GameLingo works.",
            size: 13,
            color: .secondaryLabelColor
        )
        subtitle.maximumNumberOfLines = 2

        let sourceLanguageLabel = label("Translate from", size: 13, weight: .medium)
        let sourceLanguagePopup = languagePopup(action: #selector(sourceLanguageChanged))
        self.sourceLanguagePopup = sourceLanguagePopup
        let sourceLanguageRow = row(label: sourceLanguageLabel, control: sourceLanguagePopup)

        let targetLanguageLabel = label("Translate to", size: 13, weight: .medium)
        let targetLanguagePopup = languagePopup(action: #selector(targetLanguageChanged))
        self.targetLanguagePopup = targetLanguagePopup
        let targetLanguageRow = row(label: targetLanguageLabel, control: targetLanguagePopup)

        let languageHint = label(
            "Available languages are provided by Apple Translation and Vision on this Mac.",
            size: 11,
            color: .tertiaryLabelColor
        )

        let shortcutLabel = label("Capture shortcut", size: 13, weight: .medium)
        let shortcutButton = NSButton(title: "", target: self, action: #selector(beginRecordingShortcut))
        shortcutButton.bezelStyle = .rounded
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        shortcutButton.translatesAutoresizingMaskIntoConstraints = false
        shortcutButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        self.shortcutButton = shortcutButton
        let shortcutRow = row(label: shortcutLabel, control: shortcutButton)

        let hint = label(
            "Click the button and press a combination with ⌘, ⌥, or ⌃. Esc cancels.",
            size: 11,
            color: .tertiaryLabelColor
        )

        let intervalLabel = label("Live subtitle interval", size: 13, weight: .medium)
        let intervalPopup = NSPopUpButton()
        [("Every 0.5 s", 0.5), ("Every 0.8 s", 0.8), ("Every 1.0 s", 1.0), ("Every 1.5 s", 1.5), ("Every 2.0 s", 2.0)].forEach {
            intervalPopup.addItem(withTitle: $0.0)
            intervalPopup.lastItem?.representedObject = $0.1
        }
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)
        self.intervalPopup = intervalPopup
        let intervalRow = row(label: intervalLabel, control: intervalPopup)

        let originalTextCheckbox = NSButton(
            checkboxWithTitle: "Also show the original text",
            target: self,
            action: #selector(originalTextChanged)
        )
        self.originalTextCheckbox = originalTextCheckbox

        let resetButton = NSButton(title: "Reset shortcut", target: self, action: #selector(resetShortcut))
        resetButton.bezelStyle = .inline
        resetButton.controlSize = .small

        let stack = NSStackView(views: [
            title, subtitle, separator(), sourceLanguageRow, targetLanguageRow, languageHint,
            separator(), shortcutRow, hint, intervalRow, originalTextCheckbox, resetButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(14, after: subtitle)
        stack.setCustomSpacing(5, after: targetLanguageRow)
        stack.setCustomSpacing(14, after: languageHint)
        stack.setCustomSpacing(5, after: shortcutRow)
        stack.setCustomSpacing(12, after: hint)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: effect.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: effect.bottomAnchor, constant: -20),
            sourceLanguageRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            targetLanguageRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            intervalRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func refreshControls() {
        shortcutButton?.title = preferences.captureShortcut.displayName
        if let item = intervalPopup?.itemArray.min(by: {
            abs(($0.representedObject as? Double ?? 0) - preferences.liveInterval) <
            abs(($1.representedObject as? Double ?? 0) - preferences.liveInterval)
        }) {
            intervalPopup?.select(item)
        }
        originalTextCheckbox?.state = preferences.showsOriginalText ? .on : .off
    }

    private func loadLanguages() {
        languageTask?.cancel()
        setLanguagePopupsLoading()

        languageTask = Task { [weak self] in
            let catalog = await TranslationLanguageCatalog.load()
            guard !Task.isCancelled else { return }
            self?.populateLanguagePopups(with: catalog)
        }
    }

    private func setLanguagePopupsLoading() {
        [sourceLanguagePopup, targetLanguagePopup].forEach { popup in
            popup?.removeAllItems()
            popup?.addItem(withTitle: "Loading languages…")
            popup?.isEnabled = false
        }
    }

    private func populateLanguagePopups(with catalog: TranslationLanguageCatalog) {
        populate(
            sourceLanguagePopup,
            languages: catalog.sourceLanguages,
            selectedIdentifier: preferences.sourceLanguageIdentifier
        )
        populate(
            targetLanguagePopup,
            languages: catalog.targetLanguages,
            selectedIdentifier: preferences.targetLanguageIdentifier
        )
    }

    private func populate(
        _ popup: NSPopUpButton?,
        languages: [TranslationLanguage],
        selectedIdentifier: String
    ) {
        guard let popup else { return }
        popup.removeAllItems()

        var options = languages
        if !options.contains(where: { $0.identifier == selectedIdentifier }) {
            options.append(TranslationLanguage(identifier: selectedIdentifier))
            options.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }

        options.forEach { language in
            popup.addItem(withTitle: language.displayName)
            popup.lastItem?.representedObject = language.identifier
        }
        if let selectedItem = popup.itemArray.first(where: {
            ($0.representedObject as? String) == selectedIdentifier
        }) {
            popup.select(selectedItem)
        }
        popup.isEnabled = !options.isEmpty
    }

    private func languagePopup(action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = action
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 210).isActive = true
        return popup
    }

    @objc private func beginRecordingShortcut() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        onRecordingStateChange(true)
        shortcutButton?.title = "Press the new shortcut…"
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcutEvent(event) ?? event
        }
    }

    private func handleShortcutEvent(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecordingShortcut()
            refreshControls()
            return nil
        }

        guard let shortcut = HotKeyShortcut(event: event), shortcut.isSuitableGlobalShortcut else {
            NSSound.beep()
            shortcutButton?.title = "Include ⌘, ⌥, or ⌃"
            return nil
        }

        stopRecordingShortcut()
        if onShortcutChange(shortcut) {
            refreshControls()
        } else {
            refreshControls()
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "That shortcut is not available"
            alert.informativeText = "Another app may already be using \(shortcut.displayName). Try a different combination."
            alert.runModal()
        }
        return nil
    }

    private func stopRecordingShortcut() {
        let wasRecording = isRecordingShortcut
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        isRecordingShortcut = false
        if wasRecording {
            onRecordingStateChange(false)
        }
    }

    @objc private func intervalChanged() {
        guard let interval = intervalPopup?.selectedItem?.representedObject as? Double else { return }
        preferences.liveInterval = interval
    }

    @objc private func sourceLanguageChanged() {
        guard let identifier = sourceLanguagePopup?.selectedItem?.representedObject as? String else {
            return
        }
        preferences.sourceLanguageIdentifier = identifier
        avoidIdenticalLanguagePair(changedSource: true)
        onLanguageChange()
    }

    @objc private func targetLanguageChanged() {
        guard let identifier = targetLanguagePopup?.selectedItem?.representedObject as? String else {
            return
        }
        preferences.targetLanguageIdentifier = identifier
        avoidIdenticalLanguagePair(changedSource: false)
        onLanguageChange()
    }

    private func avoidIdenticalLanguagePair(changedSource: Bool) {
        guard preferences.sourceLanguageIdentifier == preferences.targetLanguageIdentifier else {
            return
        }

        let popup = changedSource ? targetLanguagePopup : sourceLanguagePopup
        let fallback = popup?.itemArray.first(where: {
            ($0.representedObject as? String) != preferences.sourceLanguageIdentifier
        })
        guard let identifier = fallback?.representedObject as? String else { return }

        if changedSource {
            preferences.targetLanguageIdentifier = identifier
            targetLanguagePopup?.select(fallback)
        } else {
            preferences.sourceLanguageIdentifier = identifier
            sourceLanguagePopup?.select(fallback)
        }
    }

    @objc private func originalTextChanged() {
        preferences.showsOriginalText = originalTextCheckbox?.state == .on
    }

    @objc private func resetShortcut() {
        _ = onShortcutChange(.defaultCapture)
        refreshControls()
    }

    private func row(label: NSView, control: NSView) -> NSStackView {
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }
}
