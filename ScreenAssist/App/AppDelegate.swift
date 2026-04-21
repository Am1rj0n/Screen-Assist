import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var floatingPanel: FloatingGlassPanel?
    private var statusItem: NSStatusItem!

    private var toggleHotkey: HotkeyManager?
    private var captureHotkey: HotkeyManager?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Menu bar only app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        createFloatingPanel()
        setupHotkeys()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {

            if let img = NSImage(systemSymbolName: "viewfinder.circle.fill",
                                 accessibilityDescription: "ScreenAssist") {
                img.isTemplate = true
                button.image = img
            }

            button.toolTip = "ScreenAssist — click to toggle"
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Show / Hide  ⌘⇧Space",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )

        let captureItem = NSMenuItem(
            title: "Capture Screen  ⌘⇧C",
            action: #selector(fireCaptureHotkey),
            keyEquivalent: ""
        )

        let quitItem = NSMenuItem(
            title: "Quit ScreenAssist",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        toggleItem.target = self
        captureItem.target = self

        menu.addItem(toggleItem)
        menu.addItem(captureItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Floating Panel

    private func createFloatingPanel() {

        let panel = FloatingGlassPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 58),
            styleMask: [
                .nonactivatingPanel,
                .fullSizeContentView,
                .closable
            ],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let dashView = FloatingDashboardView(appDelegate: self)
        panel.contentView = NSHostingView(rootView: dashView)

        // Center top of screen
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 360) / 2
            let y = screen.frame.height - 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        floatingPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {

        // ⌘⇧Space → toggle panel
        toggleHotkey = HotkeyManager()
        toggleHotkey?.register(modifiers: [.command, .shift], keyCode: 49) { // SPACE
            [weak self] in
            self?.togglePanel()
        }

        // ⌘⇧C → capture
        captureHotkey = HotkeyManager()
        captureHotkey?.register(modifiers: [.command, .shift], keyCode: 8) { // C
            [weak self] in
            guard let self else { return }

            if let panel = self.floatingPanel, !panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
            }

            NotificationCenter.default.post(
                name: .triggerCapture,
                object: nil
            )
        }
    }

    // MARK: - Panel Actions

    @objc func togglePanel() {

        guard let panel = floatingPanel else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func fireCaptureHotkey() {

        if let panel = floatingPanel, !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        }

        NotificationCenter.default.post(
            name: .triggerCapture,
            object: nil
        )
    }

    // MARK: - Resize Panel

    func resizePanel(to height: CGFloat, animated: Bool = true) {

        guard let panel = floatingPanel else { return }

        var frame = panel.frame
        let delta = height - frame.height

        frame.size.height = height
        frame.origin.y -= delta // grow upward

        panel.setFrame(frame, display: true, animate: animated)
    }
}

// MARK: - Panel Class

class FloatingGlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Notifications

extension Notification.Name {
    static let triggerCapture = Notification.Name("SA.triggerCapture")
    static let hidePanel = Notification.Name("SA.hidePanel")
    static let showPanel = Notification.Name("SA.showPanel")
}
