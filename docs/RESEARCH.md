# Research notes — 2026-09-27

Primary sources used for the source foundation:

1. [Swift PackageDescription](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html): explicit products, targets, dependencies, platform minimums, and a tools-version declaration. Applied as separate core/menu targets and a core test target.
2. [Apple UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller): supported presentation/embedding of SwiftUI inside UIKit. Applied to the UIKit adapter.
3. [Apple scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase): observe the state of the containing scene. Applied to dismiss the menu when inactive.
4. [Apple ScenePhase.inactive](https://developer.apple.com/documentation/swiftui/scenephase/inactive): an inactive scene should pause ongoing work. The current menu creates no periodic or background work.
5. [Apple accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion): respect the system preference when animating. Applied to the panel transition.

These sources describe ordinary app UI development. No claim is made that Apple supports modifying an unrelated game's installed app, or that this project is compatible with Free Fire. Anti-cheat avoidance was not researched or implemented. Visual references were subsequently supplied; the current demo still uses its original provisional presentation.
