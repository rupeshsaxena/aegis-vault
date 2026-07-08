enum AppLifecycleEvent: Equatable, Sendable {
    case didBecomeActive
    case willResignActive
    case didEnterBackground
    case willEnterForeground
    case willTerminate
}
