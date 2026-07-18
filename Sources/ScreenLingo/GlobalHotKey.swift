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
    private let identifier: UInt32
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

        let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        guard result == noErr,
              hotKeyID.signature == GlobalHotKey.signature,
              hotKeyID.id == instance.identifier else {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async {
            instance.action()
        }
        return noErr
    }

    init(identifier: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
        self.identifier = identifier
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

        let hotKeyIdentifier = EventHotKeyID(signature: Self.signature, id: identifier)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyIdentifier,
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
