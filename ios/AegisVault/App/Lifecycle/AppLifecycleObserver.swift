import Foundation

@MainActor
protocol AppLifecycleObserver: AnyObject {
    func handle(_ event: AppLifecycleEvent, now: Date) async
}

extension AppLifecycleObserver {
    func handle(_ event: AppLifecycleEvent) async {
        await handle(event, now: Date())
    }
}
