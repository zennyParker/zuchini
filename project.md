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
- FOV slider, initially 60; current UI range 1-180 in steps of 1. This is a provisional UI range; its game-space meaning must be agreed with the host integration.
- No Speed control. The requested controls are exactly Aimbot enable/disable, Head/Neck target selection, and FOV.
- No Visuals, Misc, Settings, Account, Auto Fire, method selector, trigger selector, or additional gameplay features.
- Session-only values; backgrounding closes the panel and retains values while the process lives. Relaunch resets defaults and opens the panel again.

## Visual direction

The three screenshots supplied by the owner are visual references: near-black panel, charcoal rounded control rows, orange crosshair/header/checkmark/slider accents, light text, a Head/Neck dropdown with orange selection, and a close button. The implemented single-feature layout omits the unrelated sidebar tabs and moon button. Its header stays visible while controls scroll on short landscape screens. The reference game's background art and logos are not packaged in the standalone demo.

## What exists and what does not

`Sources/ZuchiniCore` contains validated control definitions and session state, including the `AimbotMenu` configuration. `Sources/ZuchiniMenu` contains SwiftUI presentation and a UIKit adapter. `Examples/ZuchiniDemo` is a **standalone menu preview**. Its controls update local state and emit typed host events.

**This is not yet a functioning Free Fire aimbot or a modified Free Fire IPA.** There is no game-state reader, target acquisition, head/neck bone mapping, aiming implementation, injector, or Free Fire host adapter. The existing repository is original menu source, not recovered MoNight/Monite source. The owner mentioned integration source, but it has not been located in this source repository.

The workspace also contains a supplied game ZIP and extracted `FreeFire.app`, including a `monite.zip`. Its 3,470 archive paths were inspected: no Swift, Objective-C, C/C++, headers, or Xcode project source was found. Compiled archives are not equivalent to editable integration source. They are outside Git and outside the build inputs. The old IPA's reported key prompt has not been removed or tested; the new standalone menu has no such prompt.

Before implementing actual gameplay behavior, obtain the mentioned integration source or an internal test-build API: the host startup entry point, target data and head/neck transforms, camera/aim interface, FOV units, and exact supported game build. Do not invent offsets or claim controls affect gameplay when only UI state changes. The owner explicitly rejected a standalone preview as the final deliverable; retain it only as an existing UI validation harness.

## Build and delivery

- Development machine: Windows; no local Mac/Xcode installation.
- Repository: https://github.com/zennyParker/zuchini (public).
- `.github/workflows/validate.yml` builds with Xcode on a GitHub-hosted macOS runner, runs core tests, and packages simulator and unsigned iPhone artifacts.
- The owner plans to sign/install on an available iPhone with ESign. The unsigned IPA still needs a suitable Apple certificate and provisioning profile; successful compilation does not establish installation compatibility.
- Keep signing secrets, provisioning profiles, game archives, and extracted game binaries out of this public repository.
- Artifact: `ZuchiniDemo-unsigned.ipa`. It currently installs a standalone preview, not a replacement Free Fire client.
- Apple signing reference: https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices

## Validation and completion criteria

Run `scripts/test-windows.ps1` for portable state tests and `python scripts/validate_structure.py` for project consistency. SwiftUI/UIKit are excluded on Windows, so the macOS simulator/device builds must also pass. Check `docs/VALIDATION.md` for measured results and remaining work.

On iPhone: confirm cold-launch presentation without a key prompt; checkbox behavior; exactly Head/Neck choices; dropdown closure after selection; FOV bounds; scrolling in landscape and large text; close/reopen; outside-tap dismissal; VoiceOver; background/foreground; and a 30-minute stability session. Device execution and gameplay/anti-cheat results must be reported separately from compiler success.

End-to-end acceptance additionally requires demonstrated head/neck aiming on the intended game build, FOV exclusion, immediate cessation of aim writes when disabled, and safe handling of no target, target loss, respawn, and scene changes. Test these against real game state; UI events alone do not prove them.

The complete product additionally requires the missing game integration and verified targeting on the intended internal test build. A successful standalone menu build does not satisfy that requirement.
