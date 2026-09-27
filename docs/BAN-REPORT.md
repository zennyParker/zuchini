# Reported account ban - 2026-09-27

The owner reports that the first delivered Zucchini IPA had unstable aim and that one guest account was banned. In a follow-up, the owner confirmed the exact displayed reason: **"Using a modifier."** This is user-reported device evidence, not an independently inspected ban notice. "First delivered IPA" is the owner's build identification; an exact installed filename/hash and timing relative to enabling aiming are not independently established. Do not silently associate this incident with the newly built compact-menu IPA.

The owner also reports that Monite has not caused bans in their experience. That is not evidence that Monite cannot be detected or that its code contains a guaranteed ban-prevention mechanism. No controlled comparison or server-side detection records are available.

## What the current evidence establishes

- At least one reported test ended in an account ban. Compiler success, archive integrity, or a smoother aiming trajectory cannot be treated as evidence of account safety.
- The package modifies the client by loading a replacement library. It also retains the supplied Unity binary's pre-existing modifications. Those facts are independently established by the archive and binary audits.
- Garena's [Account Ban guidance](https://ffsupport.garena.com/hc/en-us/articles/4412913789978-Account-Ban), checked on 2026-09-27, lists modified/unauthorized clients and unauthorized tools interacting with the client among ban grounds. The reported phrase does not identify which particular code path or signal caused this account's action.
- There is no evidence that unstable aim alone caused the ban. Potential explanations must remain hypotheses until there is an exact build association and relevant runtime/server evidence.
- The compact-menu revision makes the launcher movable and reduces menu dimensions. Its targeting implementation is unchanged from `stable-screen-v1`. It includes no ban-prevention fix and is not cleared for further live-account use.

## Analysis status

[MONITE-AIMING.md](MONITE-AIMING.md) records the recovered original snapshot producer, filter data flow, point selection, screen projection, trigger modes, rotation interpolation and output-write path. Cached field initialization and alternate callback ordering are not fully recovered. Neither that static reconstruction nor copying the original trajectory establishes a no-ban property.

Keep investigation offline until the actual build and failure evidence are understood. Any legitimate internal game-security validation needs an environment and accounts explicitly designated by the game team for that testing. A normal guest account is not evidence of such an environment. Do not collect account credentials, session tokens or unrelated player data to diagnose this report.
