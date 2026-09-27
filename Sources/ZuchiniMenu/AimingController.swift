#if canImport(SwiftUI)
import Foundation
import ZuchiniCore

/// Implement on the host's game/UI thread. Return copied snapshots, never live pointers.
@MainActor
public protocol AimingHost: AnyObject {
    func captureAimFrame() -> AimFrame?
    /// Return false if the frame/entity/scene is no longer current. Revalidate before writing.
    func applyAimCommand(_ command: AimCommand) -> Bool
}

/// Driven by the host's existing frame callback; creates no timers or background tasks.
@MainActor
public final class AimingController {
    public private(set) var isActive = false
    public private(set) var lastDecision = AimDecision(status: .inactive)
    private let store: MenuStore
    private weak var host: (any AimingHost)?
    private var engine = AimingEngine()

    public init(store: MenuStore, host: any AimingHost) {
        self.store = store; self.host = host
    }

    /// Call only after a playable scene and camera are ready.
    public func activate() {
        engine.reset(); isActive = true; lastDecision = AimDecision(status: .priming)
    }

    /// Call for backgrounding, match/scene changes, respawn, or host detachment.
    public func suspend() {
        isActive = false; engine.reset(); lastDecision = AimDecision(status: .inactive)
    }

    @discardableResult
    public func step(at monotonicTime: TimeInterval) -> AimDecision {
        guard isActive else { return lastDecision }
        guard let settings = AimSettings(menuState: store.state) else {
            engine.reset(); lastDecision = AimDecision(status: .invalidSettings)
            return lastDecision
        }
        // Do not even query the game while the user has disabled aiming.
        guard settings.enabled else {
            engine.reset(); lastDecision = AimDecision(status: .disabled)
            return lastDecision
        }
        guard let host else { suspend(); return lastDecision }
        let frame = host.captureAimFrame()
        guard isActive else { return lastDecision }
        guard AimSettings(menuState: store.state) == settings else {
            engine.reset(); lastDecision = AimDecision(status: .interrupted)
            return lastDecision
        }
        lastDecision = engine.update(frame: frame, settings: settings, at: monotonicTime)
        if let command = lastDecision.command {
            // Re-read settings after the external callback in case it changed the menu.
            guard AimSettings(menuState: store.state) == settings, isActive else {
                engine.reset(); lastDecision = AimDecision(status: .interrupted)
                return lastDecision
            }
            if !host.applyAimCommand(command) {
                engine.reset(); lastDecision = AimDecision(status: .invalidFrame)
            }
        }
        return lastDecision
    }
}
#endif
