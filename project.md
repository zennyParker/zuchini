# Zucchini project brief

This is the source of truth for contributors and AI agents. Read it before changing scope. Product spelling: **Zucchini**. Existing Swift modules, scheme, repository name, and artifact names retain **Zuchini** for compatibility.

## Purpose and intended users

Build an iOS, IPA-delivered mod menu with **one gameplay feature: Aimbot**. The project owner describes this as a Free Fire internal testing project for a team of **10 people** as of 2026-09-27, including a member who joined the previous day. This team affiliation and authorization are owner-provided context, not independently verified by this repository.

The owner's revised priority is a working end-to-end integration first, acknowledging that anti-cheat detection changes over time. Undetectability is not an acceptance criterion or a promised property. No detection-evasion implementation or detection test result currently exists here. Record the exact game version, environment, and observations for any future test.

## Required product behavior

- Open the menu automatically on initial app launch. Closing it leaves a small crosshair launcher for reopening.
- No key prompt, login, license server, activation step, account screen, or device allowlist in the new menu. "Global" means the menu itself has no access gate; Apple installation signing remains separate.
- A single Aimbot enable/disable control, initially off.
- A Target dropdown containing **Head** and **Neck** only, initially Neck. No Randomized or Chest options.
- FOV slider, initially 60; range 1-180 in steps of 1. The aiming engine uses a full angular cone: 60 accepts directions within 30 degrees of camera forward. The game adapter must map this explicitly.
- No Speed control. The requested controls are exactly Aimbot enable/disable, Head/Neck target selection, and FOV.
- No Visuals, Misc, Settings, Account, Auto Fire, method selector, trigger selector, or additional gameplay features.
- Session-only values; backgrounding closes the panel and retains values while the process lives. Relaunch resets defaults and opens the panel again.

## Visual direction

The three screenshots supplied by the owner are visual references: near-black panel, charcoal rounded control rows, orange crosshair/header/checkmark/slider accents, light text, a Head/Neck dropdown with orange selection, and a close button. The implemented single-feature layout omits the unrelated sidebar tabs and moon button. Its header stays visible while controls scroll on short landscape screens. The reference game's background art and logos are not packaged in the standalone demo.

## What exists and what does not

`Sources/ZuchiniCore` contains validated controls, session state, and `AimingEngine`: target selection, FOV filtering, target retention, and smooth direction calculation. `Sources/ZuchiniMenu` contains the UI and `AimingController`, which connects menu settings to a host-supplied game interface. `Examples/ZuchiniDemo` remains a **standalone menu harness** and does not instantiate a Free Fire host. See `docs/AIMING.md` for the implemented behavior and connection contract.

**This is an experimental game-integration candidate, not a verified working release.** Target selection and aim-direction math now exist and run against synthetic snapshots. An experimental Free Fire 1.132.1 adapter now exists in `Native/`: it resolves the inspected runtime methods, reads player/head/neck/camera state, checks visibility, and invokes aim rotation. It has not been run on a physical iPhone; correct gameplay and stability are not established. The existing repository is original menu source, not recovered MoNight/Monite source. The owner clarified that creating the missing logic is our task; no separate integration source has been supplied.

The original supplied game ZIP is retained outside Git as the reproducible packaging input. Its unused nested `monite.zip` distribution was inspected (3,470 paths, no editable integration source) and is now excluded from new IPAs. Extracted copies of that archive and the original menu library were removed during cleanup. The packager replaces the original menu dylib with our own code, which has no key prompt. The filename `Monite.dylib` remains solely because the unchanged game executable loads that exact path; it is not an old configuration or implementation. Required Unity/game configuration files remain intact. Startup still needs an iPhone test.

The reverse-engineered adapter must be validated on device against the inspected interface: the host startup entry point, target data and head/neck transforms, camera/aim interface, FOV units, and exact supported game build. Do not invent offsets or claim controls affect gameplay when only UI state changes. The owner explicitly rejected a standalone preview as the final deliverable; retain it only as an existing UI validation harness.

## Build and delivery

- Development machine: Windows; no local Mac/Xcode installation.
- Repository: https://github.com/zennyParker/zuchini (public).
- `.github/workflows/validate.yml` builds with Xcode on a GitHub-hosted macOS runner, runs core tests, and packages simulator and unsigned iPhone artifacts.
- The owner plans to sign/install on an available iPhone with ESign. The unsigned IPA still needs a suitable Apple certificate and provisioning profile; successful compilation does not establish installation compatibility.
- Keep signing secrets, provisioning profiles, game archives, and extracted game binaries out of this public repository.
- Artifact `Zucchini-game-runtime` contains our new runtime dylib. `scripts/package-game.py` combines it locally with the exact supplied game ZIP into a new unsigned game IPA. The existing `ZuchiniDemo-unsigned.ipa` remains only the separate UI harness.
- Current experimental runtime source: `ec1fc25bed947aac02ff4af01b40ee4f83c695c2`. The cleaned local test package is `../builds/Zucchini-FreeFire-1.132.1-clean-unsigned.ipa`; see `docs/VALIDATION.md` for package verification and CI evidence. It requires iOS 16+ and the unchanged bundle identifier `com.dts.freefireth`. Older local experimental packages were removed after validating the replacement.
- Apple signing reference: https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices

## Validation and completion criteria

Run `scripts/test-windows.ps1` for portable state tests and `python scripts/validate_structure.py` for project consistency. SwiftUI/UIKit are excluded on Windows, so the macOS simulator/device builds must also pass. Check `docs/VALIDATION.md` for measured results and remaining work.

On iPhone: confirm cold-launch presentation without a key prompt; checkbox behavior; exactly Head/Neck choices; dropdown closure after selection; FOV bounds; scrolling in landscape and large text; close/reopen; outside-tap dismissal; VoiceOver; background/foreground; and a 30-minute stability session. Device execution and gameplay/anti-cheat results must be reported separately from compiler success.

End-to-end acceptance additionally requires demonstrated head/neck aiming on the intended game build, FOV exclusion, immediate cessation of aim writes when disabled, and safe handling of no target, target loss, respawn, and scene changes. Test these against real game state; UI events alone do not prove them.

The complete product requires successful device installation/startup, verification of the experimental runtime calls and targeting, and correction of any failures on the intended test build. A successful standalone menu build does not satisfy that requirement.

See `Native/README.md` for the reverse-engineering evidence, runtime limits, packaging command, and diagnostic export. Full game dumps and analysis copies remain outside Git. No anti-cheat modifications are implemented.
