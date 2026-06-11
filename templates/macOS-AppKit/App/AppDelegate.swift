//
//  AppDelegate.swift
//  macOS-AppKit Template
//
//  NSApplicationDelegate that builds the main window and menu programmatically.
//
//  NOTE: There is intentionally NO `@main` / `@NSApplicationMain` attribute here.
//  The single entry point lives in `main.swift`, which instantiates this class
//  and calls `NSApplication.shared.run()`. Adding `@main` here would create a
//  duplicate entry point and break compilation.
//

import AppKit

// `@MainActor` isolates the whole delegate to the main actor, which Swift 6
// strict concurrency requires before touching AppKit (`NSWindow`, view
// controllers, the menu) from these callbacks. `main.swift` constructs the
// delegate from the main-actor top-level context, so this composes cleanly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Window Controllers

    /// Retains the main window controller for the lifetime of the app.
    private var mainWindowController: NSWindowController?

    /// Retains the settings window controller while it is presented.
    private var settingsWindowController: NSWindowController?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupMainWindow()

        // Bring the app to the foreground on launch.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Quit when the user closes the last window. Standard single-window-app behavior.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Main Window

    private func setupMainWindow() {
        let homeViewController = HomeViewController(viewModel: HomeViewModel())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "macOS-AppKit Template"
        window.contentViewController = homeViewController
        window.setFrameAutosaveName("MainWindow")
        window.minSize = NSSize(width: 480, height: 320)
        window.center()

        let windowController = NSWindowController(window: window)
        windowController.showWindow(self)

        self.mainWindowController = windowController
    }

    // MARK: - Settings Window

    /// Opens the Settings/Preferences UI in a dedicated window.
    /// TODO: Consider presenting as a sheet on the main window instead, if preferred.
    @objc private func openSettings(_ sender: Any?) {
        // Reuse the existing settings window if it is already open.
        if let existing = settingsWindowController {
            existing.showWindow(self)
            existing.window?.makeKeyAndOrderFront(self)
            return
        }

        let settingsViewController = SettingsViewController(viewModel: SettingsViewModel())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = settingsViewController
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(self)

        self.settingsWindowController = controller
    }

    // MARK: - Main Menu

    /// Builds a minimal but valid main menu programmatically (App + Edit menus).
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (the bold menu named after the app).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = ProcessInfo.processInfo.processName

        appMenu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        // Settings / Preferences. ⌘, is the macOS convention.
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)

        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Edit menu (basic clipboard support for text controls).
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        NSApp.mainMenu = mainMenu
    }
}
