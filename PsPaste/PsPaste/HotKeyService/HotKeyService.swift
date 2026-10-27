import Carbon
import Foundation

/// Global hot key via Carbon `RegisterEventHotKey` (ARCHITECTURE §6).
///
/// Sandbox-off distribution, so Carbon is available. Default binding ⌘⇧V;
/// configurability arrives with the settings window in M2.
@MainActor
final class HotKeyService {

    /// Default binding ⌘⇧` (Grave, the key left of 1). ⌘⇧V conflicts with
    /// Paste.app which the user still runs; configurability arrives in M2.
    nonisolated static let defaultKeyCode = UInt32(kVK_ANSI_Grave)
    nonisolated static let defaultModifiers = UInt32(cmdKey | shiftKey)

    /// Fired on the main actor when the hot key is pressed.
    var onToggle: (() -> Void)?

    /// Human-readable failure reason when `start` returns false.
    private(set) var lastError: String?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Bridges the C event handler (which cannot capture) back to the service.
    fileprivate nonisolated(unsafe) static var pendingToggle: (() -> Void)?

    static let hotKeyID = EventHotKeyID(signature: OSType(0x50735061), id: 1) // "PsPa"

    @discardableResult
    func start(
        keyCode: UInt32 = HotKeyService.defaultKeyCode,
        modifiers: UInt32 = HotKeyService.defaultModifiers
    ) -> Bool {
        stop()
        HotKeyService.pendingToggle = { [weak self] in self?.onToggle?() }

        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, Self.hotKeyID,
            GetEventDispatcherTarget(), 0, &ref
        )
        guard registerStatus == noErr else {
            lastError = "RegisterEventHotKey failed with OSStatus \(registerStatus)"
            print("[HotKeyService] \(lastError!)")
            return false
        }
        hotKeyRef = ref

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }
                var pressedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                guard pressedID.id == HotKeyService.hotKeyID.id,
                      let toggle = HotKeyService.pendingToggle else {
                    return noErr
                }
                DispatchQueue.main.async(execute: toggle)
                return noErr
            },
            1, &eventType,
            nil, &handlerRef
        )
        guard installStatus == noErr else {
            lastError = "InstallEventHandler failed with OSStatus \(installStatus)"
            print("[HotKeyService] \(lastError!)")
            stop()
            return false
        }
        return true
    }

    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        HotKeyService.pendingToggle = nil
    }
}
