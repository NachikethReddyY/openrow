import Carbon
import CoreGraphics

@MainActor enum PointerActions {
    static func click(at point: CGPoint) -> Bool {
        guard !IsSecureEventInputEnabled(), let source = CGEventSource(stateID: .privateState),
              let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else { return false }
        for event in [move, down, up] {
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    static func scroll(at point: CGPoint, vector: CGVector) {
        guard !IsSecureEventInputEnabled(), let source = CGEventSource(stateID: .privateState),
              let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                wheel1: Int32(vector.dy.rounded()), wheel2: Int32(vector.dx.rounded()), wheel3: 0)
        else { return }
        event.location = point
        event.flags = []
        event.post(tap: .cghidEventTap)
    }
}
