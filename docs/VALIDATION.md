# Validation

## Experimental game integration - 2026-09-27

The repository now contains a game-loaded adapter for the supplied Free Fire 1.132.1 build. Static inspection recovered named player, bone, camera, team, visibility, and aim-rotation methods; all 26 IL2CPP exports required by the adapter were found in its Unity binary. The custom metadata layout was normalized only in an analysis copy, with all 333,780 method records and 1,045 generic-container references checked. See [Native/README.md](../Native/README.md).

The runtime includes automatic menu presentation, disabled-by-default aiming, Head/Neck selection, FOV, conservative physics visibility checks, lifecycle suppression, stale-frame rejection, and local diagnostic export. No extra gameplay controls were added. The local packager preserves the original main executable, Unity binary, and metadata byte-for-byte, replaces the menu library, adjusts Info.plist, and removes obsolete signature resource files for full re-signing.

### Verified build and package

- Runtime source commit: `ec1fc25bed947aac02ff4af01b40ee4f83c695c2`.
- [Apple CI run 36320643952](https://github.com/zennyParker/zuchini/actions/runs/36320643952) passed: all 29 Swift tests, four packaging tests, simulator/device harness builds, native runtime build, and simulator harness launch. These tests do not execute the game adapter against Free Fire.
- Local Windows project-structure validation and all four packaging tests passed. The earlier 25 portable Swift tests passed locally; the final Apple run includes those tests and four Apple-only controller tests.
- Downloaded runtime SHA-256: `129d7c0e87eb5303a20a06f95b277ea07135f7e76de7c81a33dd84b945df106a`, matching the CI artifact hash. Mach-O platform is iOS, minimum 16.0, SDK 17.5. An earlier linker SDK mismatch was corrected before this build. The remaining deprecated-window API warning relates to the legacy Unity window fallback.
- Final local package: `../builds/Zucchini-FreeFire-1.132.1-ec1fc25-unsigned.ipa`, 986,426,168 bytes. All ZIP entries passed CRC validation, the three original game-binary hashes matched, and the packaged runtime matched the downloaded artifact.
- Final IPA SHA-256: `973f4711611b4469addf20ed21f59d7976296e7414d809cb34fb4214bb3a4c0b`. The adjacent JSON manifest records these values. The original supplied archive was not modified. Earlier experimental packages are superseded.
- The IPA is not signed for device installation. Full ESign re-signing and physical-iPhone validation remain outstanding. No full game binary or analysis dump was uploaded to GitHub.

**Physical-device installation, game startup, actual aim movement, wall checks, responsiveness, and long-session stability have not been verified.** The adapter's runtime invocation semantics and frame timing remain assumptions to check on device. Successful compiler tests and synthetic target tests do not establish these properties. No iPhone was available through the local device inventory during this run.

To test: sign the game IPA on iOS 16+ while retaining `com.dts.freefireth`, launch with aiming off, check game touch controls, then enable aiming and close the menu. Hold the closed launcher for 1.2 seconds to export a diagnostic snapshot; return it and any crash report. Full instructions are in [Native/README.md](../Native/README.md#required-iphone-validation).

## Earlier targeting engine revision - 2026-09-27

Implemented portable target selection and smooth aim-direction calculation, plus a main-actor menu/host controller. This operates on supplied snapshots and does not yet access Free Fire. See `AIMING.md`.

- All 25 portable tests pass locally on Windows, including 15 engine tests and the 10 existing menu/state tests.
- The deterministic simulation processed 72,000 frames (ten simulated minutes at 120 Hz), including periodic target loss, with 66,000 commands and no invalid output. Maximum observed angular step was about 0.346 degrees in that trajectory. This was accelerated simulation, not a ten-minute device stability test.
- Fixed-target tests cover 30/60/120 Hz, unit directions, bounded angular speed, no overshoot, and matching final directions.
- Tests also cover FOV boundaries/live changes, both bones, disabling/re-enabling, hidden/dead/allied targets, missing/invalid points, duplicates, target retention/loss, stale/repeated/future frames, stalls, and reset.
- Project structure and diff checks passed. [Apple CI run 36318139889](https://github.com/zennyParker/zuchini/actions/runs/36318139889) passed for commit `2fbc99991a565c13674577a35818115955d99ae8`: all 28 tests (including the three Apple-only controller tests), simulator and unsigned iPhone builds, simulator launch, and artifact upload. The controller tests use a fake host, not Free Fire.

At this earlier revision the game adapter was not implemented. Actual iPhone behavior, gameplay correctness, and human-like perception remain unverified. No detection-evasion result is claimed.

## Three-control scope revision - 2026-09-27

Removed Speed from the menu and the validation harness. Current controls are Aimbot enable/disable, Head/Neck, and FOV only. Updated the existing core test to exercise both FOV bounds and turning Aimbot off. All 10 core tests passed locally on Windows with zero failures; the project-structure and diff checks also passed. [Apple validation run 36317124773](https://github.com/zennyParker/zuchini/actions/runs/36317124773), for source commit `22450d47639bdda45633e0312057c19fdd677045`, was queued when this status was recorded; no Apple pass is claimed for this revision yet.

At this earlier revision there was no game adapter. An experimental adapter has since been implemented in `Native`; it still needs a physical-iPhone test. No local Free Fire gameplay test has been run; a Windows Swift test cannot run the iOS game. The standalone harness is not the requested final product.

## Previous four-control menu revision - 2026-09-27

This earlier revision contained the reference-inspired dark/orange panel with Aimbot, Head/Neck, FOV, and Speed controls. The app opened the panel on initial appearance without a key prompt. Its preview screen explicitly identified the missing game connection. The results below describe that earlier revision.

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
- Check FOV bounds 1-180/default 60 and confirm no Speed control is present.
- Portrait/landscape and larger Dynamic Type: all controls remain reachable by scrolling, and close stays visible.
- Close, outside tap, and crosshair reopening work repeatedly; background content receives taps only when uncovered.
- VoiceOver identifies controls and selection; background content is hidden from accessibility while open.
- Background/foreground and lock/unlock: panel closes; values persist for the process lifetime. Relaunch resets and opens again.
- Check Reduce Motion and the UIKit adapter's dismissal.

## Required physical-iPhone checks

- Sign/install the experimental game IPA through the owner's ESign setup; keep `com.dts.freefireth`, and record iOS version and provisioning details without committing credentials.
- Repeat interaction/orientation/lifecycle checks.
- Run 30 minutes with periodic control changes; record responsiveness, crashes, CPU/memory trends, and device temperature.

No physical-iPhone, Free Fire gameplay, targeting accuracy, prompt-free game startup, or anti-cheat detection tests have been completed. The experimental adapter is now implemented; device installation and runtime verification remain required. Do not treat UI state tests as gameplay validation.
