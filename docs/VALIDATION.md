# Validation

## Completed on Windows

- Created the Swift package, reusable source, standalone demo, project generator, and shared Xcode scheme.
- Generated the Xcode project from local source paths without third-party build dependencies.
- Checked project object references, source references, scheme XML, package paths, and CI YAML structure.
- Parsed all 10 Swift files with the installed Tree-sitter Swift grammar: no syntax errors. This is not Swift compiler/type-check validation.
- Reviewed the source's lifecycle and event paths. This is source review, not native execution.
- Copied the original ZIP outside the source folder and verified its SHA-256.
- Installed Swift 6.4.0 from the official Apple-signed Windows installer after checking its published SHA-256. Reused the existing Visual C++ tools and Windows SDK; added the installer-required Python 3.10 alongside existing Python versions and preserved Python 3.12 as the default.
- Compiled the portable package code and ran all seven `MenuStateTests` on Windows: zero failures. SwiftUI/UIKit bodies are conditionally excluded on Windows and are not covered by this build.

The structural check is repeatable with `python scripts/validate_structure.py`. The additional grammar/CI check results are recorded in `docs/windows-validation.json`.

Repeat the compiler/test validation with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1`. A regular terminal also needs the Visual C++ developer environment to find `link.exe`; the script loads it automatically and refreshes `SDKROOT`.

Non-fatal warnings observed: Swift's prebuilt WinSDK module reported a `wchar_t` module-context recovery warning, and SwiftPM could not create the optional `.build/debug` symbolic link under this account's current symlink permissions. The compiled test executable still ran successfully. Windows Developer Mode was not changed.

## Completed on the Mac build runner

The [first public CI run](https://github.com/zennyParker/zuchini/actions/runs/36314982979) passed for source commit `e4adacc38fb540261be908603fb2a67fcc217cda` on 2026-09-27:

- Xcode 15.4 (15F31d), Apple Swift 5.10, GitHub `macos-14` runner.
- Project structure validation passed.
- All seven core tests passed with zero failures.
- The standalone iOS simulator Debug build passed, compiling the SwiftUI and UIKit source.
- The standalone iPhone Release build passed with code signing disabled.
- The workflow packaged and uploaded `ZuchiniDemo-simulator.zip` and `ZuchiniDemo-unsigned.ipa` as the `ZuchiniDemo-builds` artifact, retained for 14 days.

These are compiler/build results. The demo was not launched in the simulator or on a device. The unsigned IPA requires signing and provisioning before installation. The current menu is a functional prototype; the supplied visual references have not yet been implemented.

## Still required in the simulator

- Run the demo in portrait and landscape; check panel scrolling on short displays and larger Dynamic Type sizes.
- With the menu closed, confirm the underlying canvas counter receives taps, including after repeated open/close cycles.
- With it open, confirm dismissal by the close button and outside tap, section selection, value changes, reset, and the demo action.
- Confirm VoiceOver labels and that background content is hidden from accessibility while the panel is open.
- Background/foreground and lock/unlock the demo. Confirm the panel closes and values survive while the process remains alive.
- Confirm Reduce Motion behavior and test the UIKit adapter's close and swipe-to-dismiss paths.

## Still required on the iPhone

- Sign/install the standalone demo using the user's development setup.
- Test 30 minutes with the menu open, then closed, changing controls periodically. Record CPU, memory trend, responsiveness, and device temperature; no pass result is assumed.
- Repeat orientation and lifecycle checks, including multiple scenes if the host app enables them.

This checklist establishes UI-library behavior only. It does not validate an IPA modification, the old Monite library, a Free Fire integration, or any crash fix. The earlier crash investigation is paused at the user's request.
