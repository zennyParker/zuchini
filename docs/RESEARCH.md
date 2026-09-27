# Research notes — 2026-09-27

Primary sources used for the source foundation:

1. [Swift PackageDescription](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html): explicit products, targets, dependencies, platform minimums, and a tools-version declaration. Applied as separate core/menu targets and a core test target.
2. [Apple UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller): supported presentation/embedding of SwiftUI inside UIKit. Applied to the UIKit adapter.
3. [Apple scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase): observe the state of the containing scene. Applied to dismiss the menu when inactive.
4. [Apple ScenePhase.inactive](https://developer.apple.com/documentation/swiftui/scenephase/inactive): an inactive scene should pause ongoing work. The menu handles presentation state; the subsequent native adapter also pauses its frame-driven aiming work when inactive.
5. [Apple accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion): respect the system preference when animating. Applied to the panel transition.

These sources describe ordinary app UI development. No claim is made that Apple supports modifying an unrelated game's installed app. Anti-cheat avoidance was not researched or implemented. The menu was subsequently updated from the owner's visual references. The experimental game adapter and its static reverse-engineering evidence are documented in [Native/README.md](../Native/README.md); gameplay compatibility is not yet verified.
