# Zucchini

Read [project.md](project.md) first. It defines the iOS Aimbot-only menu, the owner's testing-team context, and what remains before a working Free Fire integration exists.

The repository now also contains an [experimental game-loaded adapter](Native/README.md) and a local game-IPA packager. Device gameplay is not verified.

The source retains a **standalone native menu validation harness**, with automatic opening and no key prompt. It has an Aimbot enable/disable checkbox, Head/Neck dropdown, and FOV slider in a dark/orange panel based on the supplied references. Speed has been removed. The new aiming engine consumes these settings and computes target directions from supplied snapshots, but **Free Fire is not connected**. See [the engine and integration documentation](docs/AIMING.md). The required final deliverable is a working game integration, not this harness.

The product name is Zucchini. Swift modules, the Xcode scheme, and artifact names retain `Zuchini` for compatibility.

## Source layout

- `Sources/ZuchiniCore`: validated controls, session state, and `AimbotMenu.definition()`.
- `Sources/ZuchiniMenu`: SwiftUI panel, overlay, theme, store, and UIKit adapter.
- `Examples/ZuchiniDemo`: standalone iOS app and checked-in Xcode project.
- `Tests/ZuchiniCoreTests`: state, bounds, schema, and target-choice validation.
- `docs/VALIDATION.md`: results and device checklist.

Game archives and extracted binaries live outside this source repository and are not build dependencies. The old IPA's key layer has not been changed. This source contains no authentication or licensing layer.

## Build on GitHub from Windows

The **Validate source** workflow runs on pushes, pull requests, and manual dispatch. It uses a macOS runner with Xcode to run core tests, compile simulator and unsigned iPhone builds, and launch the simulator app for a screenshot. No local Mac is required for this workflow.

Download the **ZuchiniDemo-builds** artifact from the relevant Actions run. It contains:

- `ZuchiniDemo-unsigned.ipa`: standalone iPhone preview, requiring signing/provisioning.
- `ZuchiniDemo-simulator.zip`: simulator app.
- `ZuchiniDemo-launch.png`: actual simulator launch screenshot.

The owner's intended installation route is ESign on iPhone with their certificate and provisioning profile. Installation through ESign has not yet been verified. See [Apple's device-distribution requirements](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices). Signing secrets are not stored in Git. Artifacts expire after 14 days.

## Test the portable core on Windows

With Swift, Visual C++ Build Tools, and the Windows SDK installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1
python scripts/validate_structure.py
```

If Swift's module cache was created using a differently capitalized workspace path, use a fresh scratch directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1 -ScratchPath .build/aimbot-validation
```

SwiftUI/UIKit are conditionally excluded on Windows; passing these tests does not compile or exercise the iOS views.

## Run on a Mac

Use Xcode 15 or newer and an iOS 16+ simulator/device. Open `Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj`, select **ZuchiniDemo**, and Run. The panel opens immediately. Close it to see the preview's current control values and tap the crosshair to reopen it.

```sh
swift test
xcodebuild -project Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj \
  -scheme ZuchiniDemo -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Host integration

Add this folder as a local Swift package and link `ZuchiniCore` and `ZuchiniMenu`. Retain a `MenuStore` per scene on the main actor:

```swift
let store = MenuStore(definition: try AimbotMenu.definition())
store.onEvent = { event in
    // The host implements behavior for valueChanged(id:value:).
}
store.present()
```

Wrap host content in `ZuchiniOverlay(store: store) { MyAppContent() }`, or use `ZuchiniUIKit.makeViewController(store: store)` from UIKit. Host callbacks are synchronous and must stay brief. Dropdown values are `.choice("Head")` and `.choice("Neck")`; the remaining IDs and defaults are documented in `project.md`.

Target selection and smooth aim-direction calculation now exist in `AimingEngine`, with a main-actor `AimingController` bridge. The `Native` candidate now implements named-runtime access to Free Fire player/bone/camera state and aim rotation, plus loading through the supplied menu slot. This has only been statically inspected and compiled; device execution remains required. Detection evasion is not implemented. Integration source or an internal test-build API is needed for the next stage. A compiled preview is not evidence of functioning gameplay or undetectability.
