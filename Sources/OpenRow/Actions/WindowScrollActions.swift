import AppKit
import Carbon

/// Window-directed wheel events bypass global pointer positioning and need no private event fields.
@MainActor enum WindowScrollActions {
    static func scroll(pid: pid_t, windowNumber: Int, at point: CGPoint, vector: CGVector,
                       shouldContinue: @Sendable () -> Bool) -> Bool {
        guard shouldContinue(), !IsSecureEventInputEnabled(),
              vector.dx.isFinite, vector.dy.isFinite,
              let primaryHeight = NSScreen.screens.first?.frame.maxY,
              let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]],
              let window = windows.first(where: {
                  $0[kCGWindowLayer as String] as? Int == 0
              }),
              window[kCGWindowOwnerPID as String] as? pid_t == pid,
              let number = window[kCGWindowNumber as String] as? Int,
              number == windowNumber,
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds), frame.contains(point) else { return false }

        // The CG bridge cannot resolve another process's NSWindow. Feed it window-local
        // top-left coordinates through its primary-screen flip, preserving the window tag.
        let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        let location = ScreenGeometry.cocoaPoint(fromQuartz: local, primaryScreenMaxY: primaryHeight)
        guard let event = NSEvent.mouseEvent(with: .mouseMoved, location: location,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: number, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)?.cgEvent,
              let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                wheel1: Int32(max(Double(Int32.min), min(Double(Int32.max), vector.dy.rounded()))),
                wheel2: Int32(max(Double(Int32.min), min(Double(Int32.max), vector.dx.rounded()))), wheel3: 0) else { return false }
        event.type = .scrollWheel
        for field in [CGEventField.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2,
                      .scrollWheelEventIsContinuous, .scrollWheelEventFixedPtDeltaAxis1,
                      .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis1,
                      .scrollWheelEventPointDeltaAxis2] {
            event.setIntegerValueField(field, value: wheel.getIntegerValueField(field))
        }
        // Assigning event.location here discards the window-local routing metadata.
        // A final synchronous gate also rejects key-up, mode changes, and app switches.
        let currentWindows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        guard let currentWindow = currentWindows.first(where: { $0[kCGWindowLayer as String] as? Int == 0 }),
              currentWindow[kCGWindowNumber as String] as? Int == number,
              let currentBounds = currentWindow[kCGWindowBounds as String] as? NSDictionary,
              let currentFrame = CGRect(dictionaryRepresentation: currentBounds), currentFrame == frame,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              shouldContinue(), !IsSecureEventInputEnabled() else { return false }
        event.postToPid(pid)
        return true
    }
}
