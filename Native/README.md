# Experimental Free Fire 1.132.1 adapter

This directory builds a game-loaded runtime library. It is an experimental candidate, not a device-verified release.

Static inspection of the supplied game recovered named methods for `GameFacade.CurrentLocalPlayer`, `CurrentMatch`, `IsLocalTeammate`, `Player.get_HeadBoneTransform`, `get_NeckBone`, `get_IsDead`, `get_IsDieing`, `IsVisible`, and `SetAimRotation`. All 26 required IL2CPP exports exist in the supplied Unity binary. The adapter resolves these by name and uses `il2cpp_runtime_invoke`; it does not call guessed RVAs or alter anti-cheat code.

The supplied metadata declares version 31 but has 40-byte method records instead of the standard 36. Every one of its 333,780 method names, declaring types, and tokens validated under the 40-byte layout. All 1,045 method generic-container links identify offset +20; the extra word is at +24. Removing that word in a separate analysis copy let Il2CppDumper 6.7.46 parse successfully. The extra word's semantics remain unidentified. The original metadata is preserved in the game; the adjusted copy and full dumps stay outside Git.

Runtime behavior:

- Pinned to application version 1.132.1 and Unity Mach-O UUID `c8de7371-cba7-3e7a-9e09-30b8e1b89073`.
- No key prompt; the package replaces the existing `Monite.dylib` load slot with this project's own code. No original Monite implementation is copied.
- SwiftUI overlay opens automatically. Gameplay touches pass through when the menu is closed, except at the launcher. Aiming pauses while the menu/share sheet is open or the app is inactive.
- Enumerates loaded Player objects at most twice per second; copied samples and Unity GC handles are used instead of raw field-offset walks. It checks local-player identity, team, death/knockdown, and render visibility.
- Reads actual Head/Neck transforms and Camera.main's transform, and projects targets with WorldToViewportPoint. FOV is a screen-point radius around the game window center. Physics raycasts require an unobstructed path or a first hit belonging to the target hierarchy. At most eight candidates receive physics checks per frame, prioritizing the last applied target then screen-center distance. This budget can still miss another eligible target when the checked candidates are occluded.
- The engine retains eligible targets and uses bounded acquisition without exponential trailing error. The adapter converts the direction with Unity's LookRotation and invokes SetAimRotation. Scene/local-player changes, stale frames, missing methods, and managed exceptions suppress writes.
- No firing, server-packet changes, anti-cheat patching, or detection guarantee.

## Build and package

GitHub's macOS workflow builds `Zucchini-game-runtime`, containing `Monite.dylib` and its hash/dependency report. The game archive itself is never uploaded. On Windows, package the downloaded library with:

```powershell
python scripts/package-game.py --game <supplied-archive.zip> --library <downloaded-Monite.dylib> --output <new-unsigned.ipa>
```

The packager verifies the original main executable, Unity binary, and metadata hashes; preserves their bytes; replaces the menu library, adjusts Info.plist for iOS 16+ and local file sharing, and removes obsolete signature resource files/profiles for re-signing. All bundled resources, including the 498 MB nested `monite.zip`, are retained and checked against the original with SHA-256. That archive's runtime role is unverified; the earlier assumption that it was unused was insufficient justification for removal. `Monite.dylib` remains as a compatibility filename because the unchanged executable loads that path; its contents are our Zucchini code. The packager writes a new archive and validates all ZIP entries and the expected file inventory. Existing files are never overwritten.

## Required iPhone validation

Sign the entire output with ESign using the user's certificate/profile on iOS 16+. Keep the bundle identifier `com.dts.freefireth`; changing it causes the version guard to leave aiming inactive. Successful CI compilation and packaging do not establish installation, startup, API behavior, visibility correctness, aim rotation behavior, or stability in a match.

1. Launch with Aimbot off and confirm the menu opens without a key prompt. Close it and confirm game touch controls work.
2. In the intended controlled test environment, enable Aimbot, choose Head or Neck and an FOV, then close the menu. Opening the menu pauses aiming.
3. Confirm selection, smooth movement, FOV limits, wall occlusion, teammate exclusion, immediate disable, death/respawn, and background/foreground handling.
4. Hold the closed crosshair launcher for 1.2 seconds to share a diagnostic snapshot. The latest report is also written to `Documents/zucchini-diagnostics.json`; it contains version/status/counts/timing, not credentials, packets, or account identifiers.
5. Return that report and any iOS crash report if startup or aiming fails. These are necessary to distinguish missing runtime methods, no eligible target, rejected aim calls, and actual process faults.

The user reports that the previous IPA starts and moves the camera, but aiming quality is inadequate. This revised runtime has not been tested on a physical device. Managed exception handling cannot catch every native crash. No stability or anti-cheat result is asserted for this candidate.

See [original aiming analysis](../docs/MONITE-AIMING.md) for recovered behavior, feature inventory, and remaining uncertainties.
