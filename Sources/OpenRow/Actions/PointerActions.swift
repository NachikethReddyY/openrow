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

}
