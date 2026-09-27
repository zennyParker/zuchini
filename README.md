# Zuchini

A native iOS menu source foundation, with a standalone demo and no key prompt, licensing service, or hosting requirement. This is a new implementation, not recovered Monite source. The current presentation is a functional prototype; the supplied visual references have not yet been implemented.

The project lives inside the folder named `zucchini`; the Swift package and example retain the original proposed project name, `Zuchini`.

## What is implemented

- Reusable toggle, numeric slider, and action controls, organized into sections.
- A floating launcher and dismissible panel within the host app's own SwiftUI hierarchy.
- A theme you can change independently of the control definitions.
- A validated schema: duplicate IDs, invalid ranges, and invalid slider steps are rejected.
- Session-only state, range clamping, step normalization, and restore-defaults behavior.
- Typed host callbacks for changes and actions.
- A UIKit presentation adapter using Apple's `UIHostingController`.
- VoiceOver labels, scalable text, scrollable compact layouts, Reduce Motion support, and dismissal when the scene becomes inactive.
- A standalone demo whose controls change only its own canvas, plus core unit tests and a Mac CI workflow.

There are no timers, display links, network requests, filesystem scans, or disk persistence in the menu implementation. Event handlers execute on the main actor and should remain brief. Hosting and Cloudflare are unnecessary for this local foundation.

## Folder layout

```text
source/
    Package.swift
    Sources/
      ZuchiniCore/        Control definitions and state
      ZuchiniMenu/        SwiftUI presentation and UIKit adapter
    Examples/
      ZuchiniDemo/        Standalone iOS app and Xcode project
    Tests/
      ZuchiniCoreTests/   Input, range, reset, and isolation tests
    docs/                Architecture, research, device test checklist
    scripts/             Reproducible Xcode project generation
```

This repository contains source only. Game archives, extracted game files, and toolchain installers are outside the repository and are not build dependencies.

## Run on a Mac

Requirements: macOS with Xcode 15 or newer; iOS 16 or newer for the demo. No third-party Swift packages are required.

1. Clone this repository to the Mac.
2. Open `Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj` in Xcode.
3. Select the **ZuchiniDemo** scheme and an iPhone simulator, then Run.
4. Tap **Z**, change the grid/brightness/marker controls, and try the reset action.
5. For an actual iPhone, choose your development team in Signing & Capabilities and use your own unique bundle identifier.

From the source directory, core tests and a simulator build can also be run with:

```sh
swift test
xcodebuild -project Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj \
  -scheme ZuchiniDemo -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

The `swift test` command exercises the state/schema tests. The example app's scheme builds the app; it does not contain a UI-test target.

## Build with GitHub Actions

The **Validate source** workflow runs the core tests, builds for the iOS simulator and iPhone, and uploads the **ZuchiniDemo-builds** artifact. It runs on pushes, pull requests, or manually from the repository's Actions tab. Artifacts are retained for 14 days.

The artifact contains `ZuchiniDemo-simulator.zip` and `ZuchiniDemo-unsigned.ipa`. The IPA contains only the standalone demo and must be signed with appropriate Apple provisioning before it can be installed on an iPhone. No signing credentials are stored in the repository. A successful build does not establish on-device stability or verify the rendered UI.

## Test the core on Windows

Install the official Swift for Windows toolchain, Visual C++ build tools, and Windows SDK. This project was tested with Swift 6.4.0. Run from the source directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1
```

This script loads the installed Visual C++ environment and Swift Windows SDK for its own process, then runs the seven core tests. It does not change machine-wide execution policy. Restart existing terminals to pick up the installed Swift PATH entry; `swift --version` then shows the compiler version.

The core compiles and all seven tests pass on Windows. SwiftUI/UIKit code is conditionally excluded on this platform, so this does not validate the menu's visual implementation or generate an iPhone app. Use the Mac steps above for that.

## Integrate in an app you control

Add this folder as a local Swift package dependency and link `ZuchiniCore` and `ZuchiniMenu`.

```swift
import SwiftUI
import ZuchiniCore
import ZuchiniMenu

// Create and retain one MenuStore per scene, typically using @StateObject.
let definition = try MenuDefinition(title: "My controls", sections: [
    MenuSection(id: "display", title: "Display", controls: [
        MenuControl(id: "grid", title: "Guide grid", kind: .toggle(defaultValue: false))
    ])
])
let store = MenuStore(definition: definition)

// In a SwiftUI view's body:
ZuchiniOverlay(store: store) {
    MyAppContent()
}
```

`MenuStore` is main-actor isolated; create and use it from your UI/main-actor context. The host can observe its published state or handle `store.onEvent`. The demo demonstrates both. Avoid callbacks that strongly capture their owning store; use a weak capture when needed.

For UIKit, retain the store in your own controller/scene and present:

```swift
let controller = ZuchiniUIKit.makeViewController(store: store)
present(controller, animated: true)
```

This is supported in-app UI integration. No injector, third-party process hooks, game manipulation, anti-cheat evasion, or Free Fire integration is implemented. The controls are UI/host APIs rather than implementations of gameplay features.

## Change the UI later

Start with `Sources/ZuchiniMenu/ZuchiniPanel.swift` and `MenuTheme.swift`. Keep the core state and host callback contract intact where possible. The host's `MenuDefinition` supplies sections and labels. Screenshots alone do not define the behavior behind each control, so record that separately.

## Verification status

The source and project structure were checked on Windows. Swift 6.4.0 compiled the core and executed seven tests with zero failures on 2026-09-27. See the repository's Actions runs for Apple build results and `docs/VALIDATION.md` for remaining checks and Windows toolchain warnings. Simulator interaction, signing, and iPhone stability testing remain outstanding.

Apple's supported [SwiftUI/UIKit hosting](https://developer.apple.com/documentation/swiftui/uihostingcontroller) and the official [Swift package description](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html) informed this structure. The research notes explain the other design choices.
