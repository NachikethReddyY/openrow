import AppKit

struct DisplaySnapshot: Sendable {
    let cocoaFrame: CGRect
    let quartzFrame: CGRect
    let primaryMaxY: CGFloat
}

@MainActor final class OverlayController {
    private var panels: [NSPanel] = []
    private var views: [OverlayView] = []

    var displays: [DisplaySnapshot] {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return NSScreen.screens.map {
            DisplaySnapshot(cocoaFrame: $0.frame, quartzFrame: ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primaryMaxY), primaryMaxY: primaryMaxY)
        }
    }

    func rebuild() {
        panels.forEach { $0.close() }
        panels.removeAll()
        views.removeAll()
        for display in displays {
            let panel = NSPanel(contentRect: display.cocoaFrame,
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            panel.setAccessibilityElement(false)
            let view = OverlayView(frame: CGRect(origin: .zero, size: display.cocoaFrame.size))
            view.display = display
            view.wantsLayer = true
            view.setAccessibilityElement(false)
            panel.contentView = view
            panels.append(panel)
            views.append(view)
        }
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        views.forEach { $0.content = .none }
    }

    func showMessage(_ message: String) { show(.message(message)) }

    func showHints(targets: [TargetSnapshot], codes: [HintCode], prefix: [HintKey], size: HintSize) {
        let labels = codes.map { $0.keys.map { KeyboardLayout.label(for: $0.keyCode) }.joined() }
        show(.hints(targets, labels, HintFilter.states(for: codes, prefix: prefix), size.points))
    }

    func showRegions(_ targets: [TargetSnapshot], selected: Int) { show(.regions(targets, selected)) }

    private func show(_ content: OverlayView.Content) {
        if panels.isEmpty { rebuild() }
        for (panel, view) in zip(panels, views) {
            view.content = content
            view.needsDisplay = true
            panel.orderFrontRegardless()
        }
    }

    func announce(_ message: String) {
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}

@MainActor final class OverlayView: NSView {
    enum Content {
        case none
        case message(String)
        case hints([TargetSnapshot], [String], [HintFilterState], CGFloat)
        case regions([TargetSnapshot], Int)
    }
    var display = DisplaySnapshot(cocoaFrame: .zero, quartzFrame: .zero, primaryMaxY: 0)
    var content: Content = .none
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        switch content {
        case .none: break
        case let .message(message): drawHUD(message)
        case let .hints(targets, labels, states, size):
            var occupied: [CGRect] = []
            let components = targets.map { localRect($0.frame) }
            for index in targets.indices {
                let target = targets[index]
                guard let point = target.clickPoint ?? TargetPolicy.actionPoint(frame: target.frame, screens: [display.quartzFrame]),
                      display.quartzFrame.contains(point) else { continue }
                let local = ScreenGeometry.localPoint(fromQuartz: point, inCocoaScreenFrame: display.cocoaFrame,
                    primaryScreenMaxY: display.primaryMaxY)
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium), .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1)]
                let measured = (labels[index] as NSString).size(withAttributes: attributes)
                let placement = HintLayout.place(at: local, size: CGSize(width: measured.width + 4, height: measured.height + 2),
                    bounds: bounds.insetBy(dx: 1, dy: 1), occupied: occupied, components: components, preferredSide: target.hintSide)
                occupied.append(placement.rect)
                let color = NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.67, alpha: 1)
                drawCallout(labels[index], placement: placement, attributes: attributes,
                    fill: color, dimmed: states[index] == .dimmed,
                    selected: states[index] == .selected)
            }
        case let .regions(targets, selected):
            for (index, target) in targets.enumerated() where display.quartzFrame.intersects(target.frame) {
                let rect = localRect(target.frame).intersection(bounds).insetBy(dx: 2, dy: 2)
                guard !rect.isNull else { continue }
                let isSelected = selected == index
                NSColor.systemBlue.withAlphaComponent(isSelected ? 1 : 0.45).setStroke()
                let outline = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
                outline.lineWidth = 2
                if !isSelected { outline.setLineDash([5, 4], count: 2, phase: 0) }
                outline.stroke()
                drawBadge(String(index + 1), at: CGPoint(x: rect.minX + 3, y: rect.maxY - 3), size: 9,
                    fill: isSelected ? .systemBlue : .windowBackgroundColor, text: isSelected ? .white : .labelColor,
                    dimmed: false, selected: false)
            }
            drawHUD("Scroll · H J K L · Shift dash · Tab region · Esc close")
        }
    }

    private func localRect(_ rect: CGRect) -> CGRect {
        ScreenGeometry.cocoaRect(fromQuartz: rect, primaryScreenMaxY: display.primaryMaxY)
            .offsetBy(dx: -display.cocoaFrame.minX, dy: -display.cocoaFrame.minY)
    }

    private func drawCallout(_ label: String, placement: HintPlacement, attributes: [NSAttributedString.Key: Any],
                             fill: NSColor, dimmed: Bool, selected: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.cgContext.setAlpha(dimmed ? 0.24 : 1)
        let base = placement.base
        let vertical = placement.side == .above || placement.side == .below
        let dx: CGFloat = vertical ? 1.75 : 0
        let dy: CGFloat = vertical ? 0 : 1.75
        let pointer = NSBezierPath()
        pointer.move(to: CGPoint(x: base.x - dx, y: base.y - dy))
        pointer.line(to: placement.tip)
        pointer.line(to: CGPoint(x: base.x + dx, y: base.y + dy))
        pointer.close()
        fill.setFill()
        pointer.fill()
        (selected ? NSColor.systemBlue : NSColor(calibratedWhite: 0.25, alpha: 0.55)).setStroke()
        pointer.lineWidth = selected ? 1.5 : 0.6
        pointer.lineJoinStyle = .round
        pointer.stroke()
        let badge = NSBezierPath(roundedRect: placement.rect, xRadius: 3.5, yRadius: 3.5)
        badge.lineWidth = selected ? 1.5 : 0.6
        badge.fill()
        badge.stroke()
        (label as NSString).draw(at: CGPoint(x: placement.rect.minX + 2, y: placement.rect.minY + 1), withAttributes: attributes)
    }

    private func drawBadge(_ label: String, at point: CGPoint, size: CGFloat, fill: NSColor,
                           text: NSColor, dimmed: Bool, selected: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold), .foregroundColor: text]
        let measured = (label as NSString).size(withAttributes: attributes)
        let width = measured.width + 4
        let height = measured.height + 2
        let rect = CGRect(x: min(max(2, point.x), bounds.width - width - 2),
            y: min(max(2, point.y - height), bounds.height - height - 2), width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(dimmed ? 0.24 : 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        fill.setFill()
        path.fill()
        (selected ? NSColor.systemBlue : NSColor.black).setStroke()
        path.lineWidth = selected ? 2 : 1
        path.stroke()
        (label as NSString).draw(at: CGPoint(x: rect.minX + 2, y: rect.minY + 1), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawHUD(_ message: String) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.labelColor]
        let width = min(bounds.width - 40, (message as NSString).size(withAttributes: attrs).width + 24)
        let textRect = CGRect(x: (bounds.width - width) / 2 + 12, y: 32, width: width - 24, height: 40)
        let measured = (message as NSString).boundingRect(with: textRect.size, options: .usesLineFragmentOrigin, attributes: attrs)
        let background = CGRect(x: textRect.minX - 12, y: 24, width: width, height: measured.height + 16)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: background, xRadius: 8, yRadius: 8).fill()
        (message as NSString).draw(in: CGRect(x: textRect.minX, y: 32, width: textRect.width, height: measured.height), withAttributes: attrs)
    }
}
