//
//  AppRouter.swift
//  Swift-SwiftUI
//
//  A NavigationStack-based router/coordinator. Owns the navigation path and
//  exposes a typed Route enum plus convenience push/pop helpers. Views drive
//  navigation through the router instead of binding to raw NavigationLinks,
//  which keeps navigation logic centralized and testable.
//

import SwiftUI

// NOTE: Uses the Observation framework (@Observable), available on
// iOS 17 / macOS 14+. For earlier targets, make this a final class conforming
// to ObservableObject and mark `path` with @Published.
@Observable
@MainActor
final class AppRouter {

    /// The destinations reachable in the app. `Hashable` so values can be
    /// pushed onto a `NavigationPath`.
    enum Route: Hashable {
        case home
        case settings
        case detail(Item.ID)
        // TODO: Add new routes here as features are introduced.
    }

    /// The backing navigation path used by the root `NavigationStack`.
    var path = NavigationPath()

    init() {}

    /// Pushes a route onto the stack.
    func push(_ route: Route) {
        path.append(route)
    }

    /// Pops the top-most route, if any.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Pops back to the root view.
    func popToRoot() {
        guard !path.isEmpty else { return }
        path.removeLast(path.count)
    }
}
