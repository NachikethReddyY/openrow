/// One automatic presentation (and sound) per Mission Control visit.
struct MissionControlSession {
    enum Effect { case none, present, hide }
    private enum State { case inactive, waiting, presented, dismissed }
    private var state = State.inactive

    mutating func update(active: Bool, canPresent: Bool, hasTargets: Bool) -> Effect {
        guard active else {
            let wasActive = state != .inactive
            state = .inactive
            return wasActive ? .hide : .none
        }
        if state == .inactive { state = .waiting }
        guard canPresent else {
            let needsHide = state != .dismissed
            state = .dismissed
            return needsHide ? .hide : .none
        }
        guard state == .waiting, hasTargets else { return .none }
        state = .presented
        return .present
    }

    mutating func dismiss() {
        if state != .inactive { state = .dismissed }
    }
}
