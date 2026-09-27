import Foundation

/// Session-local normalized placement, preserving reachability after rotation/resizing.
public struct LauncherPlacement: Equatable, Sendable {
    public private(set) var horizontal: Double = 1
    public private(set) var vertical: Double = 0
    public init() {}

    public func center(width: Double, height: Double) -> (x: Double, y: Double) {
        let x = limits(width), y = limits(height)
        return (x.lowerBound + horizontal * (x.upperBound - x.lowerBound),
                y.lowerBound + vertical * (y.upperBound - y.lowerBound))
    }

    public mutating func move(x: Double, y: Double, width: Double, height: Double) {
        guard x.isFinite, y.isFinite else { return }
        let horizontalRange = limits(width), verticalRange = limits(height)
        if horizontalRange.upperBound > horizontalRange.lowerBound {
            horizontal = min(1, max(0, (x - horizontalRange.lowerBound) / (horizontalRange.upperBound - horizontalRange.lowerBound)))
        }
        if verticalRange.upperBound > verticalRange.lowerBound {
            vertical = min(1, max(0, (y - verticalRange.lowerBound) / (verticalRange.upperBound - verticalRange.lowerBound)))
        }
    }

    private func limits(_ dimension: Double) -> ClosedRange<Double> {
        let size = dimension.isFinite ? max(0, dimension) : 0
        let inset = min(30, size / 2) // 44-point button plus 8-point edge spacing.
        return inset...(size - inset)
    }
}
