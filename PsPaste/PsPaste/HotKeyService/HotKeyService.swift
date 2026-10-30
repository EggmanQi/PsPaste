import AppKit
import Carbon
import Foundation

/// Global hot key via Carbon `RegisterEventHotKey` (ARCHITECTURE §6).
///
/// Registration failures are reported through `onRegistrationStateChange` (no
/// UI in this module) and retried every `retryInterval` seconds: the app that
/// owns the hot key may quit later, so the failure state is never permanent.
@MainActor
final class HotKeyService {

    nonisolated static let defaultKeyCode = UInt32(kVK_ANSI_Grave)
    nonisolated static let defaultModifiers = UInt32(cmdKey | shiftKey)

    /// Outcome of the most recent registration attempt, exposed to the assembly layer.
    nonisolated enum RegistrationState: Equatable {
        case registered
        /// The binding is owned by another app; a retry is scheduled.
        case failed(HotKeyBinding)
    }

    /// Fired on the main actor when the hot key is pressed.
    var onToggle: (() -> Void)?

    /// Fired whenever registration succeeds or fails, including after retries.
    /// A rejected `rebind` attempt is not a state change: the caller gets
    /// `false` and the active binding stays as it was.
    var onRegistrationStateChange: ((RegistrationState) -> Void)?

    /// Pure retry gate: enough time must pass after the recorded failure.
    nonisolated static func shouldRetry(
        lastFailureAt: Date,
        now: Date,
        interval: TimeInterval
    ) -> Bool {
        now.timeIntervalSince(lastFailureAt) >= interval
    }

    /// NSEvent device-independent modifier flags → Carbon modifier mask
    /// (Task 15 recorder). The bit layouts differ between the two APIs, so
    /// map explicitly.
    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    /// Carbon modifier mask → NSEvent modifier flags (menu key equivalents).
    nonisolated static func modifierFlags(fromCarbon carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    // Carbon artifacts are process-wide singletons in practice (only one
    // registration can own a hot key) and the C event handler cannot capture
    // instance state, so they live in static storage.
    nonisolated(unsafe) private static var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private static var handlerRef: EventHandlerRef?
    nonisolated(unsafe) fileprivate static var pendingToggle: (() -> Void)?
    nonisolated static let hotKeyID = EventHotKeyID(signature: OSType(0x50735061), id: 1) // "PsPa"

    private let now: () -> Date
    private let retryInterval: TimeInterval
    /// Wraps the Carbon registration; tests replace it with a scripted sequence.
    private let registerWithCarbon: (UInt32, UInt32) -> Bool

    private var retryTimer: Timer?
    private var lastFailureAt: Date?
    private var binding = HotKeyBinding.default

    init(
        now: @escaping () -> Date = Date.init,
        retryInterval: TimeInterval = 30,
        registerWithCarbon: ((UInt32, UInt32) -> Bool)? = nil
    ) {
        self.now = now
        self.retryInterval = retryInterval
        self.registerWithCarbon = registerWithCarbon ?? Self.carbonRegister
    }

    @discardableResult
    func start(
        keyCode: UInt32 = HotKeyService.defaultKeyCode,
        modifiers: UInt32 = HotKeyService.defaultModifiers
    ) -> Bool {
        binding = HotKeyBinding(keyCode: keyCode, modifiers: modifiers)
        Self.pendingToggle = { [weak self] in self?.onToggle?() }
        return register()
    }

    /// Registers the active binding and publishes the outcome.
    @discardableResult
    private func register() -> Bool {
        guard registerWithCarbon(binding.keyCode, binding.modifiers) else {
            onRegistrationStateChange?(.failed(binding))
            scheduleRetry()
            return false
        }
        didRegister()
        return true
    }

    private func didRegister() {
        retryTimer?.invalidate()
        retryTimer = nil
        lastFailureAt = nil
        onRegistrationStateChange?(.registered)
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        Self.carbonUnregister()
        Self.pendingToggle = nil
    }

    /// Attempts a new binding at runtime (Task 15). A Carbon attempt releases
    /// the old registration first, so a conflicting candidate would leave
    /// the app without any hot key — re-register the active binding.
    @discardableResult
    func rebind(to candidate: HotKeyBinding) -> Bool {
        guard registerWithCarbon(candidate.keyCode, candidate.modifiers) else {
            register()
            return false
        }
        binding = candidate
        didRegister()
        return true
    }

    /// Re-registers once the retry interval has elapsed. Timer entry point;
    /// also directly drivable in tests via the injected clock.
    func retryIfNeeded(now overrideNow: Date? = nil) {
        guard let lastFailureAt else { return }
        let current = overrideNow ?? now()
        guard Self.shouldRetry(
            lastFailureAt: lastFailureAt,
            now: current,
            interval: retryInterval
        ) else { return }
        register()
    }

    // MARK: - Retry scheduling

    private func scheduleRetry() {
        retryTimer?.invalidate()
        lastFailureAt = now()
        retryTimer = Timer.scheduledTimer(
            withTimeInterval: retryInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.retryIfNeeded() }
        }
    }

    // MARK: - Carbon

    nonisolated static func carbonRegister(keyCode: UInt32, modifiers: UInt32) -> Bool {
        carbonUnregister()

        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetEventDispatcherTarget(), 0, &ref
        )
        guard registerStatus == noErr else { return false }
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
            carbonUnregister()
            return false
        }
        return true
    }

    nonisolated static func carbonUnregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
