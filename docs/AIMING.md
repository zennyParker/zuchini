# Aiming engine and host connection

`AimingEngine` now implements target selection and smooth aim-direction calculation. It is portable Swift with no networking, hooks, memory access, timer, randomness, or third-party dependencies. `AimingController` connects the existing menu to a host-supplied snapshot/write interface on the main actor.

This is functioning calculation code tested against synthetic game state. An [experimental Free Fire adapter](../Native/README.md) now implements this contract using methods recovered from the supplied game. Its device behavior remains unverified. The existing example app remains a separate menu harness. No claims of human indistinguishability, anti-cheat evasion, or guaranteed stability follow from these tests.

## Behavior

- Aimbot off: no host reads or aim writes. Enabling primes one valid frame before issuing a command.
- Only Head or Neck; no fallback to a different bone when the selected point is missing.
- FOV is the full angular cone in degrees around the current camera direction: 60 means +/-30 degrees. A host must map this convention explicitly.
- Only living, visible enemies with valid selected-bone positions are eligible. The host supplies these facts, including line-of-sight visibility.
- Select the nearest angular target. Stable ID ordering resolves ties, and a 3-degree advantage is required to switch away from an eligible existing target. An invalid/out-of-FOV lock is released immediately.
- No firing, prediction, random jitter, fake input, or server communication is performed.
- Fixed internal smoothing limits movement to 180 degrees/second and eases toward the point with a 0.12-second response time. There is no Speed setting. The fixed-target response uses exact integration of `d(error)/dt = -min(rate, error/timeConstant)` followed by spherical interpolation. Tests compare 30/60/120 Hz results and check overshoot and angular bounds.
- Freshness limit and maximum frame gap: 100 ms. Old/future/invalid frames produce no command. Repeated frame sequences produce no repeated writes. Resuming after a long gap primes timing rather than catching up in a large step.
- Missing targets, invalid vectors, ambiguous duplicate IDs, or more than 1,024 candidates cannot produce an aim command for the invalid input. Individual invalid candidates are excluded; invalid camera/frame data rejects the entire frame.

## Required host implementation

The actual game connection must implement `AimingHost`:

1. `captureAimFrame()` returns a copied snapshot: increasing frame sequence, monotonic capture time, world-space camera position and forward direction, and target IDs with head/neck positions and enemy/alive/visible flags. Use a distinct ID per spawn. All vectors must use the same coordinate system.
2. `applyAimCommand(_:)` validates the current scene, camera, frame sequence, and target identity, then applies the absolute unit direction using the game's own aim interface. Return false if anything changed. Do not retain or queue commands for later use.

Create `AimingController(store:host:)`, retain the host, and call `activate()` when the playable camera is ready. Call `step(clock:)` from a main-actor frame callback using the same monotonic clock as the snapshots; it samples time after capture so capture latency counts toward freshness. `step(at:)` remains available for pre-captured frames and deterministic tests. Call `suspend()` for backgrounding, scene/match changes, death/respawn, or detachment, and activate again only once current data is ready.

The controller rechecks settings after host capture. Disabling during capture suppresses the pending write. A failed host apply clears state. The host is weakly held; releasing it suspends processing. Nothing starts running merely by importing the library.

The native adapter resolves named player/bone/camera methods, reads transforms, and invokes aim rotation. Its overlay uses a display-link callback and pauses while the menu is open or the app is inactive. Real gameplay must verify coordinate behavior, invocation semantics, visibility, and ordering relative to the game's own updates. Static recovery of methods does not prove these runtime assumptions.

## Local validation

`AimingEngineTests` runs deterministic tests for target filtering, head/neck selection, FOV boundaries and changes, disabled state, target retention/loss, bad inputs, timestamp/sequence handling, stall recovery, and smoothing. A 72,000-frame simulation represents ten minutes at 120 Hz, including periodic target loss. It executes faster than real time; it is not a ten-minute device, thermal, or memory test.

`AimingControllerTests` runs on Apple platforms against an in-memory fake host. It checks read/write suppression while disabled or suspended, stale-command rejection, changes during capture, and host lifetime. Windows excludes SwiftUI, so these bridge tests require the macOS CI run.

For debug logging, record `AimDecision.status`, target ID, frame sequence, and error angle inside the internal test host. Log bounded samples locally; no hosted source or logging backend is needed. `lastDecision` contains only the latest result and does not accumulate a history.
