import Carbon
import Foundation

enum GlobalHotKeyError: Error {
    case handlerRegistrationFailed(OSStatus)
    case hotKeyRegistrationFailed(OSStatus)
}

@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    private static let signature: OSType = 0x474C4E47 // "GLNG"

    private static let callback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let result = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard result == noErr, hotKeyID.signature == GlobalHotKey.signature else {
            return OSStatus(eventNotHandledErr)
        }

        let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            instance.action()
        }
        return noErr
    }

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.handlerRegistrationFailed(handlerStatus)
        }

        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            throw GlobalHotKeyError.hotKeyRegistrationFailed(registrationStatus)
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
