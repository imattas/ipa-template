//
//  main.swift
//  macOS-AppKit Template
//
//  This is the single, explicit entry point for the application.
//
//  We deliberately bootstrap the app here instead of annotating
//  `AppDelegate` with `@main` / `@NSApplicationMain`. Using `@main`
//  on the delegate AND a `main.swift` file would create two competing
//  top-level entry points and fail to compile.
//
//  RULE: Keep exactly ONE entry point.
//    - main.swift  -> creates NSApplication, installs the delegate, runs.
//    - AppDelegate -> NO `@main` attribute (see AppDelegate.swift).
//

import AppKit

// Grab the shared application instance.
let application = NSApplication.shared

// Create and retain the delegate for the lifetime of the app.
// The delegate is responsible for building the window, menu, and UI.
let delegate = AppDelegate()
application.delegate = delegate

// Regular activation policy so the app appears in the Dock and can own windows.
application.setActivationPolicy(.regular)

// Start the main run loop. This call does not return until the app terminates.
application.run()
