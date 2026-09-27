# Aiming engine and host connection

`AimingEngine` now implements target selection and smooth aim-direction calculation. It is portable Swift with no networking, hooks, memory access, timer, randomness, or third-party dependencies. `AimingController` connects the existing menu to a host-supplied snapshot/write interface on the main actor.

This is functioning calculation code tested against synthetic game state. An [experimental Free Fire adapter](../Native/README.md) now implements this contract using methods recovered from the supplied game. The user reports startup and camera movement in the previous IPA, but inadequate aiming. The revised tracking still needs device validation. The existing example app remains a separate menu harness. No claims of human indistinguishability, anti-cheat evasion, or guaranteed stability follow from these tests.

## Behavior

- Aimbot off: no host reads or aim writes. Enabling primes one valid frame before issuing a command.
- Only Head or Neck; no fallback to a different bone when the selected point is missing.
- The native game host uses a screen-centered radius in screen points: FOV 60 means a radius of 60 points. `AimFrame.fovSpace` makes this explicit. Portable callers default to the legacy angular cone convention (60 means +/-30 degrees); `AimSettings.fovDegrees` retains its old API name for compatibility.
- Only living, visible enemies with valid selected-bone positions are eligible. The host supplies these facts, including line-of-sight visibility.
- Acquire the nearest target by the selected FOV metric. Stable ID ordering resolves ties. Retain a valid existing target regardless of competing scores; release an invalid/out-of-FOV lock immediately. Native visibility checks prioritize the last successfully applied target within the eight-raycast budget.
- No firing, prediction, random jitter, fake input, or server communication is performed.
- Rate-limited spherical interpolation caps movement at 180 degrees/second. Within one frame's travel allowance, the output tracks the selected point exactly, removing the old exponential trailing error. There is no Speed setting. Tests compare 30/60/120 Hz behavior, moving-target error, overshoot and angular bounds.
- Freshness limit and maximum frame gap: 100 ms. Old/future/invalid frames produce no command. Repeated frame sequences produce no repeated writes. Resuming after a long gap primes timing rather than catching up in a large step.
- Missing targets, invalid vectors, ambiguous duplicate IDs, or more than 1,024 candidates cannot produce an aim command for the invalid input. Individual invalid candidates are excluded; invalid camera/frame data rejects the entire frame.

## Required host implementation

The actual game connection must implement `AimingHost`:

1. `captureAimFrame()` returns a copied snapshot: increasing frame sequence, monotonic capture time, world-space camera position and forward direction, and target IDs with head/neck positions and enemy/alive/visible flags. Use a distinct ID per spawn. All vectors must use the same coordinate system.
2. `applyAimCommand(_:)` validates the current scene, camera, frame sequence, and target identity, then applies the absolute unit direction using the game's own aim interface. Return false if anything changed. Do not retain or queue commands for later use.

Create `AimingController(store:host:)`, retain the host, and call `activate()` when the playable camera is ready. Call `step(clock:)` from a main-actor frame callback using the same monotonic clock as the snapshots; it samples time after capture so capture latency counts toward freshness. `step(at:)` remains available for pre-captured frames and deterministic tests. Call `suspend()` for backgrounding, scene/match changes, death/respawn, or detachment, and activate again only once current data is ready.

The controller rechecks settings after host capture. Disabling during capture suppresses the pending write. A failed host apply clears state. The host is weakly held; releasing it suspends processing. Nothing starts running merely by importing the library.

The native adapter resolves named player/bone/camera methods, reads the main camera transform, projects the selected bone into viewport space, and invokes aim rotation. It checks camera identity before writing. Its overlay uses a display-link callback and pauses while the menu is open or the app is inactive. Real gameplay must verify coordinate behavior, invocation semantics, visibility, and ordering relative to the game's own updates. Static recovery of methods does not prove these runtime assumptions.

## Local validation

`AimingEngineTests` runs deterministic tests for target filtering, head/neck selection, FOV boundaries and changes, disabled state, target retention/loss, bad inputs, timestamp/sequence handling, stall recovery, and smoothing. A 72,000-frame simulation represents ten minutes at 120 Hz, including periodic target loss. It executes faster than real time; it is not a ten-minute device, thermal, or memory test.

`AimingControllerTests` runs on Apple platforms against an in-memory fake host. It checks read/write suppression while disabled or suspended, stale-command rejection, changes during capture, and host lifetime. Windows excludes SwiftUI, so these bridge tests require the macOS CI run.

For debug logging, record `AimDecision.status`, target ID, frame sequence, and error angle inside the internal test host. Log bounded samples locally; no hosted source or logging backend is needed. `lastDecision` contains only the latest result and does not accumulate a history.

The original binary comparison and its limits are recorded in [MONITE-AIMING.md](MONITE-AIMING.md).
