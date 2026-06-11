import WatchKit

/// WatchKit application delegate.
///
/// Conforms to `WKApplicationDelegate` to receive lifecycle callbacks and to
/// handle scheduled background refresh tasks. This class is wired into the
/// SwiftUI app via `@WKApplicationDelegateAdaptor` in `AppEntry.swift`.
final class AppDelegate: NSObject, WKApplicationDelegate {

    // MARK: - Lifecycle

    func applicationDidFinishLaunching() {
        // TODO: Perform one-time setup here (logging, dependency container,
        // analytics, scheduling the first background refresh, etc.).
        scheduleNextBackgroundRefresh()
    }

    func applicationDidBecomeActive() {
        // TODO: Restart any tasks that were paused while inactive.
    }

    func applicationWillResignActive() {
        // TODO: Pause ongoing work, save state.
    }

    // MARK: - Background Tasks

    /// Handles background tasks delivered by the system.
    ///
    /// Each task **must** be completed (via `setTaskCompletedWithSnapshot:`) once
    /// its work is done, otherwise the system will eventually penalize the app's
    /// background budget.
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // TODO: Refresh app data / fetch from the network here.
                // Re-schedule the next refresh so updates keep flowing.
                scheduleNextBackgroundRefresh()
                refreshTask.setTaskCompletedWithSnapshot(false)

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // TODO: Reconnect to the background URLSession to receive results.
                urlSessionTask.setTaskCompletedWithSnapshot(false)

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // TODO: Update UI before the snapshot is taken for the dock.
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: .distantFuture,
                    userInfo: nil
                )

            default:
                // Always complete unknown task types so we don't leak budget.
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - Scheduling

    /// Schedules the next periodic background app refresh.
    private func scheduleNextBackgroundRefresh() {
        // TODO: Tune the refresh interval to your app's needs.
        let nextRefresh = Date().addingTimeInterval(15 * 60) // 15 minutes
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: nextRefresh,
            userInfo: nil
        ) { error in
            if let error {
                // TODO: Route to your logging/telemetry pipeline.
                print("Failed to schedule background refresh: \(error)")
            }
        }
    }
}
