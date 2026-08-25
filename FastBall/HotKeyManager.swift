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
        unregister()
        guard let parsed = Accelerator.parse(accelerator) else { return false }

        self.handler = handler
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            parsed.keyCode, parsed.carbonModifiers, hotKeyID,
            GetEventDispatcherTarget(), 0, &ref
        )
        guard status == noErr, ref != nil else {
            self.handler = nil
            return false
        }
        hotKeyRef = ref
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
