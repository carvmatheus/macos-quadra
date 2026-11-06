import Carbon.HIToolbox

/// System-wide hotkeys via Carbon's RegisterEventHotKey: they work in every app and,
/// unlike a CGEventTap, need no Accessibility permission.
@MainActor
final class HotKeyCenter {
    struct Failure: Error {
        let status: OSStatus
    }

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x5144_5241 // "QDRA"

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers application-target events on the main thread.
            MainActor.assumeIsolated { center.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// `keyCode` is a kVK_* virtual key, `modifiers` a mask of cmdKey/controlKey/optionKey/shiftKey.
    /// Fails with eventHotKeyExistsErr when another app already owns the combination.
    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) throws(Failure) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { throw Failure(status: status) }
        refs.append(ref)
        handlers[id] = handler
    }
}
