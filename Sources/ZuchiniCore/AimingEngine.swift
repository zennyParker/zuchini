import Foundation

public enum AimTargetPoint: String, Equatable, Sendable {
    case head = "Head"
    case neck = "Neck"
}

/// A world-space vector. Every input must use the host's same coordinate system.
public struct AimVector: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x; self.y = y; self.z = z
    }

    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    /// Scaled normalization avoids overflow for large finite coordinates.
    public func normalized() -> AimVector? {
        guard isFinite else { return nil }
        let scale = max(abs(x), max(abs(y), abs(z)))
        guard scale > 1e-12 else { return nil }
        let a = x / scale, b = y / scale, c = z / scale
        let length = sqrt(a * a + b * b + c * c)
        return AimVector(a / length, b / length, c / length)
    }

    public static func - (lhs: AimVector, rhs: AimVector) -> AimVector {
        AimVector(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    public func dot(_ other: AimVector) -> Double { x * other.x + y * other.y + z * other.z }

    public func angleDegrees(to other: AimVector) -> Double? {
        guard let a = normalized(), let b = other.normalized() else { return nil }
        return acos(min(1, max(-1, a.dot(b)))) * 180 / .pi
    }
}

public struct AimSettings: Equatable, Sendable {
    public let enabled: Bool
    public let targetPoint: AimTargetPoint
    /// Full cone angle: FOV 60 accepts directions up to 30 degrees off camera forward.
    public let fovDegrees: Double

    public init(enabled: Bool, targetPoint: AimTargetPoint, fovDegrees: Double) {
        self.enabled = enabled; self.targetPoint = targetPoint; self.fovDegrees = fovDegrees
    }

    public init?(menuState: MenuState) {
        guard case let .toggle(enabled)? = menuState.value(for: "aimbot.enabled"),
              case let .choice(target)? = menuState.value(for: "aimbot.target"),
              let point = AimTargetPoint(rawValue: target),
              case let .number(fov)? = menuState.value(for: "aimbot.fov"),
              fov.isFinite, (1...180).contains(fov) else { return nil }
        self.init(enabled: enabled, targetPoint: point, fovDegrees: fov)
    }
}

public struct AimCandidate: Equatable, Sendable {
    /// Must identify this spawn, not just a reusable entity slot.
    public let id: String
    public let head: AimVector?
    public let neck: AimVector?
    public let isEnemy: Bool
    public let isAlive: Bool
    /// Host must supply line-of-sight visibility, not just on-screen visibility.
    public let isVisible: Bool

    public init(id: String, head: AimVector?, neck: AimVector?,
                isEnemy: Bool, isAlive: Bool, isVisible: Bool) {
        self.id = id; self.head = head; self.neck = neck
        self.isEnemy = isEnemy; self.isAlive = isAlive; self.isVisible = isVisible
    }
}

public struct AimFrame: Equatable, Sendable {
    public let sequence: UInt64
    /// Seconds from the same monotonic clock passed to update(at:).
    public let capturedAt: TimeInterval
    public let cameraOrigin: AimVector
    public let cameraForward: AimVector
    public let candidates: [AimCandidate]

    public init(sequence: UInt64, capturedAt: TimeInterval, cameraOrigin: AimVector,
                cameraForward: AimVector, candidates: [AimCandidate]) {
        self.sequence = sequence; self.capturedAt = capturedAt
        self.cameraOrigin = cameraOrigin; self.cameraForward = cameraForward
        self.candidates = candidates
    }
}

public struct AimCommand: Equatable, Sendable {
    public let targetID: String
    public let targetPoint: AimTargetPoint
    /// Absolute unit direction in the input coordinate system, not an Euler angle.
    public let direction: AimVector
    public let frameSequence: UInt64
}

public enum AimStatus: String, Sendable {
    case inactive, disabled, invalidSettings, invalidFrame, staleFrame
    case waitingForFrame, priming, interrupted, noTarget, tracking
}

public struct AimDecision: Equatable, Sendable {
    public let status: AimStatus
    public let command: AimCommand?
    public let errorDegrees: Double?

    public init(status: AimStatus, command: AimCommand? = nil, errorDegrees: Double? = nil) {
        self.status = status; self.command = command; self.errorDegrees = errorDegrees
    }
}

/// Pure, synchronous targeting math. It never reads memory, fires, or writes game state.
/// One engine per active camera. Feed its output back only through a host-owned aim API.
public struct AimingEngine: Sendable {
    public private(set) var lockedTargetID: String?
    private var lastUpdate: TimeInterval?
    private var lastSequence: UInt64?
    private var lastCapture: TimeInterval?
    private var lastPoint: AimTargetPoint?

    // Fixed implementation parameters, not additional product controls.
    private let maximumAge = 0.1
    private let maximumFrameGap = 0.1
    private let responseTime = 0.12
    private let maximumAngularRate = Double.pi  // 180 degrees per second
    private let switchAdvantage = 3.0 * Double.pi / 180

    public init() {}

    public mutating func reset() {
        lockedTargetID = nil; lastUpdate = nil; lastSequence = nil
        lastCapture = nil; lastPoint = nil
    }

    public mutating func update(frame: AimFrame?, settings: AimSettings, at now: TimeInterval) -> AimDecision {
        guard settings.enabled else { return stop(.disabled) }
        guard settings.fovDegrees.isFinite, (1...180).contains(settings.fovDegrees) else {
            return stop(.invalidSettings)
        }
        guard let frame else { return stop(.invalidFrame) }
        guard now.isFinite, now >= 0, frame.capturedAt.isFinite, frame.capturedAt >= 0,
              frame.capturedAt <= now, frame.cameraOrigin.isFinite,
              let forward = frame.cameraForward.normalized(), frame.candidates.count <= 1024 else {
            return stop(.invalidFrame)
        }
        guard now - frame.capturedAt <= maximumAge else { return stop(.staleFrame) }
        if let previous = lastUpdate, now <= previous { return stop(.invalidFrame) }
        if let sequence = lastSequence {
            if frame.sequence < sequence { return stop(.invalidFrame) }
            if frame.sequence == sequence { return AimDecision(status: .waitingForFrame) }
        }
        if let capture = lastCapture, frame.capturedAt <= capture { return stop(.invalidFrame) }

        let delta = lastUpdate.map { now - $0 }
        lastUpdate = now; lastSequence = frame.sequence; lastCapture = frame.capturedAt
        if lastPoint != settings.targetPoint { lockedTargetID = nil }
        lastPoint = settings.targetPoint
        if let delta, delta > maximumFrameGap {
            lockedTargetID = nil
            return AimDecision(status: .interrupted)
        }

        // Ambiguous duplicate IDs are excluded; selection never depends on array order.
        var counts: [String: Int] = [:]
        for candidate in frame.candidates { counts[candidate.id, default: 0] += 1 }
        var best: Selection?
        var retained: Selection?
        let halfFov = settings.fovDegrees * .pi / 360
        for candidate in frame.candidates {
            guard !candidate.id.isEmpty, counts[candidate.id] == 1,
                  candidate.isEnemy, candidate.isAlive, candidate.isVisible,
                  let point = settings.targetPoint == .head ? candidate.head : candidate.neck,
                  let direction = (point - frame.cameraOrigin).normalized() else { continue }
            let angle = acos(min(1, max(-1, forward.dot(direction))))
            guard angle <= halfFov + 1e-12 else { continue }
            let selection = Selection(id: candidate.id, direction: direction, angle: angle)
            if candidate.id == lockedTargetID { retained = selection }
            if let current = best {
                if angle < current.angle - 1e-12 ||
                    (abs(angle - current.angle) <= 1e-12 && candidate.id < current.id) {
                    best = selection
                }
            } else { best = selection }
        }
        guard var selected = best else {
            lockedTargetID = nil
            return AimDecision(status: .noTarget)
        }
        if let retained, retained.angle <= selected.angle + switchAdvantage { selected = retained }
        lockedTargetID = selected.id
        guard let delta else { return AimDecision(status: .priming) }

        let direction = smoothed(from: forward, to: selected.direction, angle: selected.angle, delta: delta)
        let command = AimCommand(targetID: selected.id, targetPoint: settings.targetPoint,
                                 direction: direction, frameSequence: frame.sequence)
        return AimDecision(status: .tracking, command: command, errorDegrees: selected.angle * 180 / .pi)
    }

    private mutating func stop(_ status: AimStatus) -> AimDecision {
        reset()
        return AimDecision(status: status)
    }

    /// Exact integration of d(error)/dt = -min(maximumAngularRate, error/responseTime)
    /// for a stationary target. Approach is bounded, continuous and cannot overshoot.
    private func smoothed(from: AimVector, to: AimVector, angle: Double, delta: Double) -> AimVector {
        guard angle > 1e-10 else { return to }
        let threshold = maximumAngularRate * responseTime
        let remaining: Double
        if angle > threshold {
            let linearTime = (angle - threshold) / maximumAngularRate
            if delta <= linearTime { remaining = angle - maximumAngularRate * delta }
            else { remaining = threshold * exp(-(delta - linearTime) / responseTime) }
        } else { remaining = angle * exp(-delta / responseTime) }
        let fraction = min(1, max(0, 1 - remaining / angle))
        let denominator = sin(angle) // Accepted targets are within 90 degrees.
        let a = sin((1 - fraction) * angle) / denominator
        let b = sin(fraction * angle) / denominator
        return AimVector(a * from.x + b * to.x, a * from.y + b * to.y,
                         a * from.z + b * to.z).normalized() ?? from
    }

    private struct Selection {
        let id: String
        let direction: AimVector
        let angle: Double
    }
}
