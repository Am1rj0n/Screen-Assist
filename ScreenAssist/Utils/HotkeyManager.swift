import Cocoa

final class HotkeyManager {

    // MARK: - Internal Key Type

    struct Hotkey: Hashable {
        let keyCode: UInt16
        let flags: UInt64

        static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
            lhs.keyCode == rhs.keyCode && lhs.flags == rhs.flags
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(flags)
        }
    }

    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var handlers: [Hotkey: () -> Void] = [:]

    // MARK: - Init

    init() {
        start()
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    func register(modifiers: NSEvent.ModifierFlags,
                  keyCode: UInt16,
                  action: @escaping () -> Void) {

        let flags = convert(modifiers)
        let hotkey = Hotkey(keyCode: keyCode, flags: flags)

        handlers[hotkey] = action
    }

    // MARK: - Event Tap

    private func start() {
        let mask = (1 << CGEventType.keyDown.rawValue)

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in

                guard type == .keyDown,
                      let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()

                manager.handle(event)

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )

        guard let eventTap else {
            print("❌ Failed to create event tap (check Input Monitoring permission)")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event Handling

    private func handle(_ event: CGEvent) {

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        let flags = event.flags

        let normalized = convert(flags)

        let hotkey = Hotkey(keyCode: keyCode, flags: normalized)

        handlers[hotkey]?()
    }

    // MARK: - Modifier Conversion

    private func convert(_ modifiers: NSEvent.ModifierFlags) -> UInt64 {
        var result: UInt64 = 0

        if modifiers.contains(.command)  { result |= 1 << 0 }
        if modifiers.contains(.shift)    { result |= 1 << 1 }
        if modifiers.contains(.option)   { result |= 1 << 2 }
        if modifiers.contains(.control)  { result |= 1 << 3 }

        return result
    }

    private func convert(_ flags: CGEventFlags) -> UInt64 {
        var result: UInt64 = 0

        if flags.contains(.maskCommand)   { result |= 1 << 0 }
        if flags.contains(.maskShift)     { result |= 1 << 1 }
        if flags.contains(.maskAlternate) { result |= 1 << 2 }
        if flags.contains(.maskControl)   { result |= 1 << 3 }

        return result
    }
}
