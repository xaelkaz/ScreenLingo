import AppKit
import Carbon
import Foundation

struct HotKeyShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let defaultCapture = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "T"
    )

    static let repeatRegion = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "R"
    )

    static let toggleLive = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "S"
    )

    var displayName: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    var isSuitableGlobalShortcut: Bool {
        let primaryModifiers = UInt32(cmdKey | optionKey | controlKey)
        return modifiers & primaryModifiers != 0
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let label = Self.label(for: event)
        guard !label.isEmpty else { return nil }

        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers,
            keyLabel: label
        )
    }

    private static func label(for event: NSEvent) -> String {
        let keyCode = Int(event.keyCode)
        if let functionNumber = functionKeyNumber(for: keyCode) {
            return "F\(functionNumber)"
        }

        switch keyCode {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            return event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? ""
        }
    }

    private static func functionKeyNumber(for keyCode: Int) -> Int? {
        let mapping = [
            kVK_F1: 1, kVK_F2: 2, kVK_F3: 3, kVK_F4: 4, kVK_F5: 5,
            kVK_F6: 6, kVK_F7: 7, kVK_F8: 8, kVK_F9: 9, kVK_F10: 10,
            kVK_F11: 11, kVK_F12: 12, kVK_F13: 13, kVK_F14: 14, kVK_F15: 15,
            kVK_F16: 16, kVK_F17: 17, kVK_F18: 18, kVK_F19: 19, kVK_F20: 20
        ]
        return mapping[keyCode]
    }
}

final class GameLingoPreferences {
    private enum Key {
        static let shortcutKeyCode = "captureShortcut.keyCode"
        static let shortcutModifiers = "captureShortcut.modifiers"
        static let shortcutLabel = "captureShortcut.label"
        static let liveInterval = "live.interval"
        static let showsOriginalText = "overlay.showsOriginalText"
        static let lastRegion = "capture.lastRegion"
        static let sourceLanguage = "translation.sourceLanguage"
        static let targetLanguage = "translation.targetLanguage"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var captureShortcut: HotKeyShortcut {
        get {
            guard defaults.object(forKey: Key.shortcutKeyCode) != nil,
                  defaults.object(forKey: Key.shortcutModifiers) != nil,
                  let label = defaults.string(forKey: Key.shortcutLabel) else {
                return .defaultCapture
            }
            return HotKeyShortcut(
                keyCode: UInt32(defaults.integer(forKey: Key.shortcutKeyCode)),
                modifiers: UInt32(defaults.integer(forKey: Key.shortcutModifiers)),
                keyLabel: label
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Key.shortcutKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Key.shortcutModifiers)
            defaults.set(newValue.keyLabel, forKey: Key.shortcutLabel)
        }
    }

    var liveInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Key.liveInterval)
            return stored == 0 ? 0.8 : min(max(stored, 0.5), 3.0)
        }
        set {
            defaults.set(min(max(newValue, 0.5), 3.0), forKey: Key.liveInterval)
        }
    }

    var showsOriginalText: Bool {
        get {
            guard defaults.object(forKey: Key.showsOriginalText) != nil else { return true }
            return defaults.bool(forKey: Key.showsOriginalText)
        }
        set { defaults.set(newValue, forKey: Key.showsOriginalText) }
    }

    var sourceLanguageIdentifier: String {
        get { defaults.string(forKey: Key.sourceLanguage) ?? "en" }
        set { defaults.set(newValue, forKey: Key.sourceLanguage) }
    }

    var targetLanguageIdentifier: String {
        get { defaults.string(forKey: Key.targetLanguage) ?? "es" }
        set { defaults.set(newValue, forKey: Key.targetLanguage) }
    }

    var lastRegion: CGRect? {
        get {
            guard let value = defaults.string(forKey: Key.lastRegion) else { return nil }
            let region = NSRectFromString(value)
            return region.width > 0 && region.height > 0 ? region : nil
        }
        set {
            if let newValue {
                defaults.set(NSStringFromRect(newValue), forKey: Key.lastRegion)
            } else {
                defaults.removeObject(forKey: Key.lastRegion)
            }
        }
    }

    func resetCaptureShortcut() {
        captureShortcut = .defaultCapture
    }
}
