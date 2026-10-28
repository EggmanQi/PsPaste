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
        case failed(String)
    }

    /// Fired on the main actor when the hot key is pressed.
    var onToggle: (() -> Void)?

    /// Fired whenever registration succeeds or fails, including after retries.
    var onRegistrationStateChange: ((RegistrationState) -> Void)?

    /// Human-readable failure reason of the most recent attempt.
    private(set) var lastError: String?

    /// Pure retry gate: enough time must pass after the recorded failure.
    nonisolated static func shouldRetry(
        lastFailureAt: Date,
        now: Date,
        interval: TimeInterval
    ) -> Bool {
        now.timeIntervalSince(lastFailureAt) >= interval
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
    private var lastKeyCode = HotKeyService.defaultKeyCode
    private var lastModifiers = HotKeyService.defaultModifiers

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
        lastKeyCode = keyCode
        lastModifiers = modifiers
        retryTimer?.invalidate()
        retryTimer = nil
        Self.pendingToggle = { [weak self] in self?.onToggle?() }

        guard registerWithCarbon(keyCode, modifiers) else {
            lastError = "RegisterEventHotKey failed: hot key already owned by another app"
            onRegistrationStateChange?(.failed(lastError!))
            scheduleRetry()
            return false
        }

        lastError = nil
        lastFailureAt = nil
        onRegistrationStateChange?(.registered)
        return true
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        Self.carbonUnregister()
        Self.pendingToggle = nil
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
        start(keyCode: lastKeyCode, modifiers: lastModifiers)
    }

    // MARK: - Retry scheduling

    private func scheduleRetry() {
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
