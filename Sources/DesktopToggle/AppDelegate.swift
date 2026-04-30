import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var globalMonitor: Any?
    private var iconsHidden = false
    private var isToggling = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        iconsHidden = readCurrentState()
        setupStatusBar()
        startMonitoring()
    }

    // MARK: - State

    private func readCurrentState() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.finder", "CreateDesktop"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "1"
        return output == "0"
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Desktop Icons", action: #selector(toggleFromMenu), keyEquivalent: "t")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit DesktopToggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: iconsHidden ? "eye.slash" : "eye",
                               accessibilityDescription: nil)
        button.toolTip = iconsHidden
            ? "Desktop icons hidden — click desktop to show"
            : "Desktop icons visible — click desktop to hide"
    }

    // MARK: - Global Mouse Monitoring

    private func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.onGlobalClick()
        }
    }

    private func onGlobalClick() {
        guard !isToggling, isDesktopPoint(NSEvent.mouseLocation) else { return }
        DispatchQueue.main.async { self.toggle() }
    }

    // Returns true when the mouse position is not covered by any visible on-screen window
    // (menu bar, dock, and app windows all have layer >= 0 and will block the check).
    private func isDesktopPoint(_ point: NSPoint) -> Bool {
        // NSScreen.screens[0] is always the primary display.
        // CGWindowListCopyWindowInfo uses CG coordinates (origin top-left of primary screen),
        // while NSEvent.mouseLocation uses AppKit coordinates (origin bottom-left). Flip Y.
        guard let primaryScreen = NSScreen.screens.first else { return false }
        let cgPoint = CGPoint(x: point.x, y: primaryScreen.frame.height - point.y)

        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return true }

        for info in list {
            // Desktop-level windows are deeply negative; skip them.
            guard (info[kCGWindowLayer as String] as? Int ?? -1) >= 0 else { continue }
            // Skip fully-transparent windows (e.g. invisible overlays from other apps).
            guard (info[kCGWindowAlpha as String] as? Double ?? 0) > 0.05 else { continue }
            guard let b = info[kCGWindowBounds as String] as? [String: Any],
                  let x = b["X"] as? Double, let y = b["Y"] as? Double,
                  let w = b["Width"] as? Double, let h = b["Height"] as? Double else { continue }
            if CGRect(x: x, y: y, width: w, height: h).contains(cgPoint) { return false }
        }
        return true
    }

    // MARK: - Toggle

    @objc private func toggleFromMenu() { toggle() }

    private func toggle() {
        guard !isToggling else { return }
        isToggling = true
        iconsHidden.toggle()
        updateIcon()

        let value = iconsHidden ? "false" : "true"
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c",
            "defaults write com.apple.finder CreateDesktop -bool \(value) && killall Finder"]
        try? task.run()

        // Finder takes ~2 s to restart; ignore clicks during that window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isToggling = false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}
