import Carbon.HIToolbox
import Foundation

/// Global hotkey via Carbon's RegisterEventHotKey.
///
/// Deliberately not NSEvent.addGlobalMonitorForEvents — that path (which is what
/// Electron's globalShortcut uses) requires Accessibility permission. This one does not.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?
    private static var shared: HotKeyManager?

    private let signature: OSType = 0x46_42_41_4C // 'FBAL'

    init() {
        HotKeyManager.shared = self
        installHandler()
    }

    /// Returns false if the combination is unparseable or already taken by another app.
    @discardableResult
    func register(_ accelerator: String, handler: @escaping () -> Void) -> Bool {
        guard let parsed = Accelerator.parse(accelerator) else { return false }

        var newRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            parsed.keyCode, parsed.carbonModifiers, hotKeyID,
            GetEventDispatcherTarget(), 0, &newRef
        )
        guard status == noErr, newRef != nil else {
            return false
        }

        // Commit the new registration only after success
        if let oldRef = hotKeyRef {
            UnregisterEventHotKey(oldRef)
        }
        hotKeyRef = newRef
        self.handler = handler
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        handler = nil
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, _ -> OSStatus in
            HotKeyManager.shared?.handler?()
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
