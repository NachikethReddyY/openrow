import Carbon
import CoreGraphics
import Foundation
import os

private func openRowTapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                               _ event: CGEvent, _ context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let context else { return Unmanaged.passUnretained(event) }
    return Unmanaged<GlobalInput>.fromOpaque(context).takeUnretainedValue().handle(type, event)
}

/// The tap owns a dedicated run loop. Shared state is confined to a short unfair-lock operation.
final class GlobalInput: @unchecked Sendable {
    private struct TapSource: @unchecked Sendable {
        let port: CFMachPort
        let source: CFRunLoopSource
    }
    private let state: OSAllocatedUnfairLock<InputSession>
    private var workerState = OSAllocatedUnfairLock<WorkerState>(initialState: WorkerState())
    private struct WorkerState: @unchecked Sendable {
        var runLoop: CFRunLoop?
        var stopped = true
    }
    private let deliver: @MainActor @Sendable (InputCommand, UInt64) -> Void
    private var tap: CFMachPort?
    private var thread: Thread?

    init(preferences: UserPreferences, deliver: @escaping @MainActor @Sendable (InputCommand, UInt64) -> Void) {
        state = OSAllocatedUnfairLock(initialState: InputSession(preferences: preferences))
        self.deliver = deliver
    }

    @MainActor func start() -> Bool {
        stop()
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: openRowTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }
        tap = port
        state.withLock { $0.resetFailure() }
        // Each worker keeps its own lifetime state, so a late old worker cannot clear a new run loop.
        workerState = OSAllocatedUnfairLock(initialState: WorkerState(stopped: false))
        let holder = TapSource(port: port, source: source)
        let worker = Thread { [holder, workerState] in
            let loopState = WorkerState(runLoop: CFRunLoopGetCurrent(), stopped: false)
            let shouldRun = workerState.withLock { value in
                guard !value.stopped else { return false }
                value.runLoop = loopState.runLoop
                return true
            }
            guard shouldRun, let loop = loopState.runLoop else { return }
            CFRunLoopAddSource(loop, holder.source, .commonModes)
            CGEvent.tapEnable(tap: holder.port, enable: true)
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, holder.source, .commonModes)
            workerState.withLock { $0.runLoop = nil }
        }
        worker.name = "OpenRow input"
        worker.qualityOfService = .userInteractive
        thread = worker
        worker.start()
        return true
    }

    @MainActor func stop() {
        configure(mode: .idle, enabled: false)
        workerState.withLock {
            $0.stopped = true
            if let loop = $0.runLoop {
                CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(loop) }
                CFRunLoopWakeUp(loop)
            }
        }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        thread = nil
    }

    @discardableResult func configure(mode: OpenRowMode, enabled: Bool, preferences: UserPreferences? = nil) -> UInt64 {
        state.withLock {
            $0.configure(mode: mode, enabled: enabled, preferences: preferences)
            return $0.epoch
        }
    }

    func accepts(_ command: InputCommand, epoch: UInt64) -> Bool {
        state.withLock { command == .tapFailed ? $0.failed : $0.epoch == epoch && !$0.failed }
    }
    func heldScrollState() -> (Set<KeyCode>, Bool) { state.withLock { ($0.scrollKeys, $0.dash) } }
    var currentEpoch: UInt64 { state.withLock { $0.epoch } }
    func isScrolling(epoch: UInt64) -> Bool {
        state.withLock { $0.epoch == epoch && $0.enabled && !$0.failed && $0.router.mode == .scroll && !$0.scrollKeys.isEmpty }
    }

    // A file-scope C callback avoids inheriting start()'s MainActor isolation.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let secure = IsSecureEventInputEnabled()
        let flags = event.flags
        let key = KeyCode(rawValue: UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode)))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let result: (RouteDecision, UInt64) = state.withLock { value in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                return (value.route(.tapDisabled), value.epoch)
            }
            let modifiers = InputModifiers(flags: flags)
            if type == .flagsChanged {
                return (value.route(.modifiersChanged(modifiers), secure: secure), value.epoch)
            }
            let event: InputEvent = type == .keyUp ? .keyUp(key, modifiers: modifiers) : .keyDown(key, modifiers: modifiers, isRepeat: isRepeat)
            let decision = value.route(event, secure: secure)
            return (decision, value.epoch)
        }
        if let command = result.0.command {
            DispatchQueue.main.async { [deliver] in deliver(command, result.1) }
        }
        return result.0.shouldConsume ? nil : Unmanaged.passUnretained(event)
    }
}
