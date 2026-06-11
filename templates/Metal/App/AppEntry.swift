//
//  AppEntry.swift
//  Metal Template
//
//  The SwiftUI entry point. Hosts the Metal-backed view full-screen.
//

import SwiftUI

@main
struct MetalTemplateApp: App {
    var body: some Scene {
        WindowGroup {
            MetalView()
                .ignoresSafeArea()           // Let Metal own the full screen.
                .statusBarHidden()
        }
    }
}
