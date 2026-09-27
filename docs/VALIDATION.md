# Validation

## Aimbot menu revision - 2026-09-27

The source now contains the reference-inspired dark/orange panel with Aimbot, Head/Neck, FOV, and Speed controls. The app opens the panel on initial appearance without a key prompt. Its preview screen explicitly identifies the missing game connection.

- Project-structure validation passed on Windows.
- All 10 portable core tests passed on Windows (Swift 6.4.0), with zero failures.
- [Apple CI run 36316574094](https://github.com/zennyParker/zuchini/actions/runs/36316574094) passed for source commit `7c07730cc0f98078718f83003aba2bb35daa78e0`: all 10 core tests, simulator Debug build, unsigned iPhone Release build, packaging, simulator installation/launch/screenshot, and artifact upload.
- Inspected the actual simulator launch PNG: the menu opens without a prompt, all four controls fit in portrait, and the dark/orange styling and default Neck/FOV 60/Speed 1.00 values render correctly. This was visual inspection of the initial screen, not an interaction test.
- Downloaded the three build artifacts to the workspace's `builds/run-36316574094/`. Verified the IPA contains `Payload/ZuchiniDemo.app`, its executable, bundle ID `com.example.zuchini.demo`, and minimum iOS version 16.0.
- The initial Windows attempt hit duplicate `vcruntime` module-cache entries caused by `Downloads`/`downloads` path casing. The retry uses a fresh scratch directory; no prior build files were deleted.
- The first Apple attempt caught a throwing call inside `StateObject`'s nonthrowing autoclosure. Moving configuration construction outside that initializer fixed the error; the successful run above includes the correction.

The earlier [baseline CI run](https://github.com/zennyParker/zuchini/actions/runs/36314982979) passed seven tests and both builds for commit `e4adacc38fb540261be908603fb2a67fcc217cda`. Those results predate this UI revision and are not evidence for the changed views.

## Repeatable checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1 -ScratchPath .build/aimbot-validation
python scripts/validate_structure.py
```

Windows tests exclude SwiftUI/UIKit. The GitHub workflow additionally compiles both Apple targets, installs and launches the simulator app, captures its initial screen, and verifies that the launched process can be terminated. A launch screenshot does not establish interactive behavior.

## Required interaction checks

- Cold-launch: panel opens without key/auth prompts.
- Toggle Aimbot; close/reopen; confirm the preview shows the retained state.
- Expand Target: exactly Head and Neck, one selected; choosing either updates state and collapses options.
- Check FOV bounds 1-180/default 60 and Speed bounds 0.05-1.00/default 1.00.
- Portrait/landscape and larger Dynamic Type: all controls remain reachable by scrolling, and close stays visible.
- Close, outside tap, and crosshair reopening work repeatedly; background content receives taps only when uncovered.
- VoiceOver identifies controls and selection; background content is hidden from accessibility while open.
- Background/foreground and lock/unlock: panel closes; values persist for the process lifetime. Relaunch resets and opens again.
- Check Reduce Motion and the UIKit adapter's dismissal.

## Required physical-iPhone checks

- Sign/install the standalone IPA through the owner's ESign setup; record iOS version and provisioning details without committing credentials.
- Repeat interaction/orientation/lifecycle checks.
- Run 30 minutes with periodic control changes; record responsiveness, crashes, CPU/memory trends, and device temperature.

No physical-iPhone, Free Fire gameplay, targeting accuracy, key-removal, or anti-cheat detection tests have been completed for this revision. The integration source or internal test-build API is still required. Do not treat UI state tests as gameplay validation.
