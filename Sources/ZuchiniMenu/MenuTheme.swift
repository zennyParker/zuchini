#if canImport(SwiftUI)
import SwiftUI

public struct MenuTheme {
    public let accent: Color
    public let surface: Color
    public let text: Color
    public let secondaryText: Color
    public let panelWidth: CGFloat

    public init(
        accent: Color = Color(red: 1, green: 0.29, blue: 0.035),
        surface: Color = Color(red: 0.043, green: 0.055, blue: 0.075),
        text: Color = .white,
        secondaryText: Color = Color(white: 0.74),
        panelWidth: CGFloat = 560
    ) {
        self.accent = accent
        self.surface = surface
        self.text = text
        self.secondaryText = secondaryText
        self.panelWidth = panelWidth.isFinite ? max(240, min(panelWidth, 600)) : 360
    }
}
#endif
