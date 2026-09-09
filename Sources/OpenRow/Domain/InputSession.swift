/// Pure tap state: key ownership and failure are independent of asynchronously rendered mode state.
struct InputSession: Sendable {
    var router: InputRouter
    private(set) var enabled = false
    private(set) var failed = false
    private(set) var epoch: UInt64 = 0
    private(set) var consumed = Set<KeyCode>()
    private(set) var scrollKeys = Set<KeyCode>()
    var dash = false

    init(preferences: UserPreferences) {
        router = InputRouter(clickShortcut: preferences.clickShortcut, scrollShortcut: preferences.scrollShortcut)
    }

    mutating func configure(mode: OpenRowMode, enabled: Bool, preferences: UserPreferences? = nil) {
        if let preferences {
            router = InputRouter(clickShortcut: preferences.clickShortcut, scrollShortcut: preferences.scrollShortcut)
        }
        router.mode = failed ? .idle : mode
        self.enabled = enabled && !failed
        epoch &+= 1
        scrollKeys.removeAll(keepingCapacity: true)
    }

    mutating func resetFailure() {
        failed = false
        consumed.removeAll(keepingCapacity: true)
        configure(mode: .idle, enabled: false)
    }

    mutating func route(_ event: InputEvent, secure: Bool = false) -> RouteDecision {
        if event == .tapDisabled {
            failed = true
            enabled = false
            epoch &+= 1
            consumed.removeAll(keepingCapacity: true)
            scrollKeys.removeAll(keepingCapacity: true)
            dash = false
            return router.route(.tapDisabled)
        }
        if secure || !enabled {
            let wasActive = router.mode != .idle
            router.mode = .idle
            consumed.removeAll(keepingCapacity: true)
            scrollKeys.removeAll(keepingCapacity: true)
            dash = false
            return wasActive ? RouteDecision(passingThrough: .cancel) : .passThrough
        }
        switch event {
        case let .modifiersChanged(modifiers):
            dash = modifiers.contains(.shift)
            return .passThrough
        case let .keyUp(key, modifiers):
            dash = modifiers.contains(.shift)
            scrollKeys.remove(key)
            guard consumed.remove(key) != nil else { return .passThrough }
            let decision = router.route(.keyUp(key, modifiers: modifiers))
            return RouteDecision(shouldConsume: true, command: decision.command)
        case let .keyDown(key, modifiers, _):
            dash = modifiers.contains(.shift)
            let decision = router.route(event)
            if decision.shouldConsume { consumed.insert(key) }
            if case .setScroll(_, true, _) = decision.command { scrollKeys.insert(key) }
            if decision.command == .cancel {
                router.mode = .idle
                scrollKeys.removeAll(keepingCapacity: true)
            }
            switch decision.command {
            case .cycleRegion, .selectRegion:
                epoch &+= 1
                scrollKeys.removeAll(keepingCapacity: true)
            default: break
            }
            return decision
        case .tapDisabled: return .passThrough
        }
    }
}
