import AppKit
import ApplicationServices
import Carbon
import CoreGraphics

/// Tracks the physical unlock-key state and modifier state using a monotonic clock.
struct UnlockGesture {
    /// Physical ANSI U key shared by event matching and hardware polling.
    static let keyCode = CGKeyCode(kVK_ANSI_U)

    /// Required uninterrupted hold duration in nanoseconds.
    static let duration: UInt64 = 2_000_000_000

    /// Whether the unlock key is currently held according to the latest event or hardware sample.
    private(set) var keyDown = false

    /// Whether all three required modifiers are held in the latest sample.
    private var modifiersDown = false
    /// Monotonic nanosecond timestamp of the uninterrupted hold, or nil when idle.
    private var startedAt: UInt64?

    /// Updates physical state without restarting an existing uninterrupted hold.
    /// - Parameters:
    ///   - keyPressed: The latest unlock-key state, or nil to preserve the previous state.
    ///   - modifiers: Whether Control, Option and Command are all down.
    ///   - now: Current monotonic uptime in nanoseconds.
    mutating func update(keyPressed: Bool? = nil, modifiers: Bool, now: UInt64) {
        if let keyPressed {
            keyDown = keyPressed
        }
        modifiersDown = modifiers
        if keyDown, modifiersDown {
            if startedAt == nil {
                startedAt = now
            }
        } else {
            startedAt = nil
        }
    }

    /// Routes key events through the same physical-key match used in production.
    /// - Parameters:
    ///   - code: Hardware key code from the event.
    ///   - type: Key event kind; other kinds preserve the current key state.
    ///   - modifiers: Whether all required modifiers are held.
    ///   - now: Current monotonic uptime in nanoseconds.
    mutating func receive(code: CGKeyCode, type: CGEventType, modifiers: Bool, now: UInt64) {
        let keyPressed: Bool? = code == Self.keyCode && (type == .keyDown || type == .keyUp)
            ? type == .keyDown : nil
        update(keyPressed: keyPressed, modifiers: modifiers, now: now)
    }

    /// Reports whether the current hold has reached the required duration.
    /// - Parameter now: Current monotonic uptime in nanoseconds.
    /// - Returns: True only for a complete, uninterrupted hold.
    func completed(at now: UInt64) -> Bool {
        guard let startedAt, now >= startedAt else {
            return false
        }

        return now - startedAt >= Self.duration
    }
}

/// Owns the event tap and its visible, mouse-accessible escape controls.
@MainActor
final class CatLockDelegate: NSObject, NSApplicationDelegate {
    /// Active keyboard filter; nil means input must pass through.
    private var tap: CFMachPort?
    /// Main-run-loop source retaining the event tap until cleanup.
    private var source: CFRunLoopSource?
    /// Mouse-accessible indication and escape menu, present only while filtering.
    private var statusItem: NSStatusItem?
    /// Main-run-loop health and physical-key sampler, invalidated before teardown.
    private var timer: Timer?
    /// Current uninterrupted keyboard escape gesture.
    private var gesture = UnlockGesture()

    /// Defers filter creation until AppKit has completed launch.
    /// - Parameter notification: AppKit launch notification; its payload is unused.
    func applicationDidFinishLaunching(_: Notification) {
        // Start only after AppKit has finished setting up the application.
        DispatchQueue.main.async { [weak self] in
            self?.lock()
        }
    }

    /// Ensures app termination releases the keyboard filter.
    /// - Parameter notification: AppKit termination notification; its payload is unused.
    func applicationWillTerminate(_: Notification) {
        releaseTap()
    }

    /// Creates the keyboard filter only after permissions and secure-input checks pass.
    private func lock() {
        guard AXIsProcessTrusted() else {
            permissionHelp()

            return
        }
        guard !IsSecureEventInputEnabled() else {
            failureHelp("Secure Keyboard Entry is active. Turn it off in the app that enabled it, then reopen CatLock. Your keyboard is not locked.")

            return
        }
        installTap()
    }

    /// Creates the C callback bridge and attaches its source to the main run loop.
    private func installTap() {
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(1) << 14) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        // The application retains its delegate until app.run returns; the tap is invalidated before that.
        let context = unsafe Unmanaged.passUnretained(self).toOpaque()
        // Core Graphics borrows the delegate context until this tap is invalidated.
        let candidateTap = unsafe CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                // The callback context is the live delegate borrowed above.
                guard let context = unsafe userInfo else {
                    // Core Graphics owns the event for the complete callback.
                    return unsafe Unmanaged.passUnretained(event)
                }
                // The source is attached only to the main run loop; this callback runs on the main actor.
                let swallow = MainActor.assumeIsolated {
                    // The live tap borrows the delegate retained by the application entry point.
                    let owner = unsafe Unmanaged<CatLockDelegate>
                        .fromOpaque(context).takeUnretainedValue()

                    return owner.receive(type: type, event: event)
                }

                // Passing through borrows the event without changing Core Graphics ownership.
                return unsafe swallow ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: unsafe context,
        )
        guard let createdTap = candidateTap else {
            permissionHelp()

            return
        }
        guard let createdSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0) else {
            CFMachPortInvalidate(createdTap)
            permissionHelp()

            return
        }
        tap = createdTap
        source = createdSource
        CFRunLoopAddSource(CFRunLoopGetMain(), createdSource, .commonModes)
        showStatus()
        CGEvent.tapEnable(tap: createdTap, enable: true)
        startMonitor()
    }

    /// Schedules health checks in common modes so the status menu cannot pause recovery.
    private func startMonitor() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            // This timer is installed on the main run loop from the main actor.
            MainActor.assumeIsolated {
                self?.checkHealth()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Samples hardware state and stops filtering if tap health or secure input changes.
    private func checkHealth() {
        guard let tap, CGEvent.tapIsEnabled(tap: tap), !IsSecureEventInputEnabled() else {
            unlock()

            return
        }
        let flags = CGEventSource.flagsState(.hidSystemState)
        let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        gesture.update(
            keyPressed: CGEventSource.keyState(.hidSystemState, key: UnlockGesture.keyCode),
            modifiers: flags.intersection(required) == required,
            now: DispatchTime.now().uptimeNanoseconds,
        )
        if gesture.completed(at: DispatchTime.now().uptimeNanoseconds) {
            unlock()
        }
    }

    /// Swallows keyboard events while maintaining the hold gesture; fails open on tap disablement.
    /// - Parameters:
    ///   - type: The event kind delivered by Core Graphics.
    ///   - event: Borrowed event, valid for the duration of this callback.
    /// - Returns: True to swallow, false to leave the event unchanged.
    private func receive(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Never silently re-enable a failed tap: returning to normal input is safer.
            unlock()

            return false
        }
        guard tap != nil else {
            return false
        }
        let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let modifiers = event.flags.intersection(required) == required
        // Repeated keyDown preserves the original hold start.
        gesture.receive(
            code: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            type: type,
            modifiers: modifiers,
            now: DispatchTime.now().uptimeNanoseconds,
        )

        return true
    }

    /// Installs a mouse-accessible status menu after event-tap creation succeeds.
    private func showStatus() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Cat Lock: keyboard locked")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        item.button?.image = image
        item.button?.title = ""
        item.button?.setAccessibilityLabel("Cat Lock: keyboard locked")
        item.button?.toolTip = "CatLock: keyboard locked; mouse remains available"
        let menu = NSMenu()
        let hint = NSMenuItem(title: "⌃⌥⌘U — hold for 2 seconds", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        let unlockItem = NSMenuItem(title: "Unlock", action: #selector(unlock), keyEquivalent: "")
        unlockItem.target = self
        menu.addItem(unlockItem)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(unlock), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    /// Explains the missing permission without claiming keyboard filtering is active.
    private func permissionHelp() {
        failureHelp("Allow CatLock in System Settings → Privacy & Security → Accessibility, then quit and open CatLock again. If macOS also requests Input Monitoring, allow CatLock there. Your keyboard is not locked.")
    }

    /// Presents recovery guidance and exits without locking input.
    /// - Parameter explanation: Actionable reason filtering could not start.
    private func failureHelp(_ explanation: String) {
        let alert = NSAlert()
        alert.messageText = "CatLock could not lock the keyboard"
        alert.informativeText = explanation
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Quit")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    /// Removes the filter before terminating so ordinary keyboard input resumes.
    @objc private func unlock() {
        releaseTap()
        NSApp.terminate(nil)
    }

    /// Idempotently tears down filtering, monitoring and status UI.
    private func releaseTap() {
        timer?.invalidate()
        timer = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }
}

/// Starts the app, or tests gesture logic without initializing AppKit or an event tap.
@main
struct CatLock {
    /// Runs the app unless the explicit, non-locking gesture self-test was requested.
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") {
            selfTest()

            return
        }
        let app = NSApplication.shared
        let delegate = CatLockDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    /// Verifies fixed gesture samples without creating AppKit or an event tap.
    /// - Precondition: The built-in gesture implementation satisfies its fixed regression cases.
    private static func selfTest() {
        var gesture = UnlockGesture()
        gesture.receive(code: CGKeyCode(kVK_Escape), type: .keyDown, modifiers: true, now: 0)
        precondition(!gesture.completed(at: 3_000_000_000), "old Escape must not start unlock")
        gesture.receive(code: UnlockGesture.keyCode, type: .keyDown, modifiers: true, now: 4_000_000_000)
        precondition(!gesture.completed(at: 5_999_999_999), "U must be held for two seconds")
        gesture.receive(code: UnlockGesture.keyCode, type: .keyDown, modifiers: true, now: 5_000_000_000)
        precondition(gesture.completed(at: 6_000_000_000), "U repeat must preserve start")
        gesture.receive(code: UnlockGesture.keyCode, type: .keyUp, modifiers: true, now: 6_000_000_001)
        precondition(!gesture.completed(at: 9_000_000_000), "U release cancels")
        gesture.receive(code: UnlockGesture.keyCode, type: .keyDown, modifiers: true, now: 10_000_000_000)
        gesture.receive(code: UnlockGesture.keyCode, type: .keyUp, modifiers: true, now: 11_000_000_000)
        precondition(!gesture.completed(at: 12_000_000_000), "early U release cancels")
        gesture.receive(code: UnlockGesture.keyCode, type: .keyDown, modifiers: true, now: 13_000_000_000)
        gesture.update(modifiers: false, now: 14_000_000_000)
        precondition(!gesture.completed(at: 15_000_000_000), "early modifier release cancels")
        gesture.update(modifiers: true, now: 16_000_000_000)
        precondition(!gesture.completed(at: 17_999_999_999))
        precondition(gesture.completed(at: 18_000_000_000))
        precondition(!gesture.completed(at: 15_000_000_000), "clock cannot run backward")
        print("CatLock gesture self-test passed")
    }
}
