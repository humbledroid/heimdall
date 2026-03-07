import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    // Shared environment service for the entire app
    let environmentService = EnvironmentService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — we're menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)

        setupStatusBar()
        setupPopover()
        setupEventMonitor()

        // Kick off environment detection
        Task {
            await environmentService.detect()
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "iphone.gen1.motion",
                accessibilityDescription: "Heimdall"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let contentView = MainPopoverView(environmentService: environmentService)

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 420, height: 580)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(sender)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Ensure popover window becomes key
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
