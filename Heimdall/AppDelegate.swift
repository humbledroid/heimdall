import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var logViewerWindows: [String: LogViewerWindowController] = [:]

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
                systemSymbolName: "macbook.and.iphone",
                accessibilityDescription: "Heimdall"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        let event = NSApp.currentEvent

        // Right-click shows context menu with Quit option
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "About Heimdall", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Heimdall", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
            button.performClick(nil)
            // Clear the menu so left-click goes back to popover
            statusItem?.menu = nil
            return
        }

        // Left-click toggles the popover
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Log Viewer

    /// Open a log viewer window for a given device/emulator.
    /// Re-uses existing windows for the same serial.
    /// Deferred to next run-loop tick so the popover can settle first.
    func openLogViewer(deviceName: String, serial: String) {
        print("[Heimdall:DEBUG] openLogViewer called — device: \(deviceName), serial: \(serial)")
        print("[Heimdall:DEBUG] Current activation policy: \(NSApp.activationPolicy().rawValue) (0=regular, 1=accessory, 2=prohibited)")
        print("[Heimdall:DEBUG] Existing log windows: \(logViewerWindows.keys.joined(separator: ", "))")

        // Reuse existing window
        if let existing = logViewerWindows[serial] {
            print("[Heimdall:DEBUG] Reusing existing window for serial: \(serial)")
            NSApp.setActivationPolicy(.regular)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        print("[Heimdall:DEBUG] Creating new log viewer window (deferred to next run loop)")

        // Defer window creation so the transient popover can dismiss cleanly
        DispatchQueue.main.async { [self] in
            print("[Heimdall:DEBUG] DispatchQueue.main.async fired — creating LogViewerWindowController")

            let controller = LogViewerWindowController(
                deviceName: deviceName,
                serial: serial,
                environmentService: environmentService
            )
            print("[Heimdall:DEBUG] LogViewerWindowController created, window: \(String(describing: controller.window))")

            // Clean up reference when window closes
            controller.window?.delegate = self
            logViewerWindows[serial] = controller

            // Switch to regular app so standalone windows can appear
            print("[Heimdall:DEBUG] Setting activation policy to .regular")
            NSApp.setActivationPolicy(.regular)
            print("[Heimdall:DEBUG] Activation policy now: \(NSApp.activationPolicy().rawValue)")

            print("[Heimdall:DEBUG] Calling showWindow + orderFrontRegardless + activate")
            controller.showWindow(nil)
            controller.window?.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)

            print("[Heimdall:DEBUG] Window visible: \(controller.window?.isVisible ?? false)")
            print("[Heimdall:DEBUG] Window frame: \(String(describing: controller.window?.frame))")
            print("[Heimdall:DEBUG] Total log viewer windows: \(logViewerWindows.count)")
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

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Remove the log viewer controller for this window
        logViewerWindows = logViewerWindows.filter { $0.value.window !== window }

        // Revert to accessory (menu-bar-only) when no log windows remain
        if logViewerWindows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
