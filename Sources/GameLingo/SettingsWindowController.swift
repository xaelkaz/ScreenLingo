import AppKit
import Carbon

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: GameLingoPreferences
    private let onShortcutChange: (HotKeyShortcut) -> Bool
    private let onRecordingStateChange: (Bool) -> Void
    private var window: NSWindow?
    private var shortcutButton: NSButton?
    private var intervalPopup: NSPopUpButton?
    private var originalTextCheckbox: NSButton?
    private var keyMonitor: Any?
    private var isRecordingShortcut = false

    init(
        preferences: GameLingoPreferences,
        onShortcutChange: @escaping (HotKeyShortcut) -> Bool,
        onRecordingStateChange: @escaping (Bool) -> Void
    ) {
        self.preferences = preferences
        self.onShortcutChange = onShortcutChange
        self.onRecordingStateChange = onRecordingStateChange
    }

    func show() {
        if window == nil {
            buildWindow()
        }
        refreshControls()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        stopRecordingShortcut()
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopRecordingShortcut()
    }

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 290),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ajustes de GameLingo"
        window.isReleasedWhenClosed = false
        window.sharingType = .none
        window.delegate = self
        self.window = window

        let effect = NSVisualEffectView()
        effect.material = .sidebar
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = effect

        let title = label("Preferencias", size: 22, weight: .bold)
        let subtitle = label(
            "Personaliza cómo activas GameLingo y la frecuencia del modo automático.",
            size: 13,
            color: .secondaryLabelColor
        )
        subtitle.maximumNumberOfLines = 2

        let shortcutLabel = label("Atajo para traducir región", size: 13, weight: .medium)
        let shortcutButton = NSButton(title: "", target: self, action: #selector(beginRecordingShortcut))
        shortcutButton.bezelStyle = .rounded
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        shortcutButton.translatesAutoresizingMaskIntoConstraints = false
        shortcutButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        self.shortcutButton = shortcutButton
        let shortcutRow = row(label: shortcutLabel, control: shortcutButton)

        let hint = label(
            "Haz clic en el botón y presiona una combinación con ⌘, ⌥ o ⌃. Esc cancela.",
            size: 11,
            color: .tertiaryLabelColor
        )

        let intervalLabel = label("Frecuencia de subtítulos", size: 13, weight: .medium)
        let intervalPopup = NSPopUpButton()
        [("Cada 0.5 s", 0.5), ("Cada 0.8 s", 0.8), ("Cada 1.0 s", 1.0), ("Cada 1.5 s", 1.5), ("Cada 2.0 s", 2.0)].forEach {
            intervalPopup.addItem(withTitle: $0.0)
            intervalPopup.lastItem?.representedObject = $0.1
        }
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)
        self.intervalPopup = intervalPopup
        let intervalRow = row(label: intervalLabel, control: intervalPopup)

        let originalTextCheckbox = NSButton(
            checkboxWithTitle: "Mostrar también el texto original en inglés",
            target: self,
            action: #selector(originalTextChanged)
        )
        self.originalTextCheckbox = originalTextCheckbox

        let resetButton = NSButton(title: "Restablecer atajo", target: self, action: #selector(resetShortcut))
        resetButton.bezelStyle = .inline
        resetButton.controlSize = .small

        let stack = NSStackView(views: [
            title, subtitle, separator(), shortcutRow, hint, intervalRow, originalTextCheckbox, resetButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(16, after: subtitle)
        stack.setCustomSpacing(5, after: shortcutRow)
        stack.setCustomSpacing(16, after: hint)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: effect.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: effect.bottomAnchor, constant: -20),
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

    @objc private func beginRecordingShortcut() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        onRecordingStateChange(true)
        shortcutButton?.title = "Presiona el nuevo atajo…"
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
            shortcutButton?.title = "Incluye ⌘, ⌥ o ⌃"
            return nil
        }

        stopRecordingShortcut()
        if onShortcutChange(shortcut) {
            refreshControls()
        } else {
            refreshControls()
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Ese atajo no está disponible"
            alert.informativeText = "Otra aplicación ya puede estar usando \(shortcut.displayName). Prueba una combinación diferente."
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
