import Cocoa
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotKeyPressed: (() -> Void)?

    private init() {
        installEventHandler()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr && hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    HotKeyManager.shared.onHotKeyPressed?()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    func register(combo: HotKeyCombo) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x534E_4950), id: 1) // 'SNIP'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    static func displayString(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }

        let keyName: String
        switch Int(keyCode) {
        case kVK_Space: keyName = "Espacio"
        case kVK_Return: keyName = "↩"
        case kVK_Tab: keyName = "⇥"
        case kVK_Delete: keyName = "⌫"
        case kVK_Escape: keyName = "⎋"
        default:
            if let chars = characters?.uppercased(), !chars.isEmpty {
                keyName = chars
            } else {
                keyName = "Key(\(keyCode))"
            }
        }
        return result + keyName
    }
}

final class ShortcutRecorderWindow: NSPanel {
    var onShortcutRecorded: ((HotKeyCombo) -> Void)?
    private let label = NSTextField(labelWithString: "")

    init(currentCombo: HotKeyCombo) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.title = "Configurar Atajo Global — SnipText"
        self.isFloatingPanel = true
        self.level = .floating
        self.center()

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 150))

        let titleField = NSTextField(labelWithString: "Presiona la nueva combinación de teclas:")
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.alignment = .center
        titleField.frame = NSRect(x: 20, y: 105, width: 320, height: 22)
        container.addSubview(titleField)

        label.stringValue = "Actual: \(currentCombo.displayString)"
        label.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        label.alignment = .center
        label.textColor = .controlAccentColor
        label.frame = NSRect(x: 20, y: 58, width: 320, height: 34)
        container.addSubview(label)

        let hintField = NSTextField(labelWithString: "Usa al menos ⌘, ⌥ o ⌃ + una tecla (Esc para cancelar)")
        hintField.font = NSFont.systemFont(ofSize: 11)
        hintField.textColor = .secondaryLabelColor
        hintField.alignment = .center
        hintField.frame = NSRect(x: 20, y: 20, width: 320, height: 18)
        container.addSubview(hintField)

        self.contentView = container
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            self.close()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let hasPrimaryModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        guard hasPrimaryModifier else {
            NSSound.beep()
            return
        }

        let carbonMods = HotKeyManager.carbonModifiers(from: flags)
        let display = HotKeyManager.displayString(
            keyCode: event.keyCode,
            flags: flags,
            characters: event.charactersIgnoringModifiers
        )
        let combo = HotKeyCombo(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonMods,
            displayString: display
        )
        label.stringValue = display
        onShortcutRecorded?(combo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.close()
        }
    }
}
