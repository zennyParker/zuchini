# Original aiming analysis and tracking revision

Inspected locally on 2026-09-27. Input is the original supplied `Monite.dylib`, SHA-256 `b64d66b7df7ef7692914e293029d1fefede168eb0cdd6852d9d8051073d2d430`. Addresses below are unslid library virtual addresses, not offsets to copy into a runtime. This is a partial reconstruction from compiled code, not recovered source or an execution trace.

## What was recovered

The library uses chained imports. Decoding those records resolved all **444 import stubs**, with 816 bound slots and 27,428 rebase records. This corrected an earlier generic symbol-mapping limitation and made the math and memory-call paths identifiable. Parsing follows Apple's [chained-fixup definitions](https://github.com/apple-oss-distributions/dyld/blob/main/include/mach-o/fixup-chains.h).

String transforms were reconstructed statically: four byte-operation variants combine rotations, arithmetic, XOR and a substitution table. The varying seed/branch scaffolding converges on the same transform within each variant. The scanner recognized **1,923 decoder functions** and recovered readable strings at **1,498 direct call sites**. Those counts include repeated labels and non-game strings; they are not feature counts. Indirect calls and non-ASCII strings are not covered. No original code was loaded or run.

### Selection and rotation path

| Evidence | Observed behavior |
| --- | --- |
| `0xbcc0b8`, `0xbcc170` onward | Clears the selected-target slot, obtains a snapshot and visits candidates. This path does not demonstrate persistent target locking. |
| `0xbce3ec`–`0xbce454` | Checks snapshot flags and a distance limit. Exact meanings of all snapshot flags remain to be linked to their producer. |
| `0xbce458`–`0xbce738` | Selects a point from a bone table, with multiple optional interpolated points and a zero-position fallback. Exact enum-to-bone mapping is not fully reconstructed. |
| `0xbce73c`–`0xbce7f8` | Projects the point, rejects nonfinite/behind-camera projections, and computes distance from screen center. In the default branch the FOV value is the initial screen-distance threshold; another priority branch minimizes a stored world-distance value. Do not equate this to a full angular cone. |
| `0xbce7fc`–`0xbce814` | Stores the chosen entity and world point for downstream aiming. |
| `0xbcd2b8` onward | Branches by trigger setting before the rotation path. Multiple modes exist; not all enum meanings are resolved. |
| `0xbcf93c`, helper `0xbd4858` | Obtains an origin through a no-argument object getter, transform getter and position getter; falls back through `0xbd8fa8`. The primary chain is consistent with main-camera position, but the cached runtime addresses are not yet independently mapped to every named method. |
| `0xbcf990`–`0xbcfa40` | Rejects invalid/zero positions and target-origin distances below 0.1, then constructs a look quaternion from target minus origin with world-up `(0,1,0)`. Helpers: `0xbda944`, `0xbdaca0`. |
| `0xbcfa54`–`0xbcfac0` | Reads the aim-speed value. At **0.95 or higher**, uses the desired quaternion directly. Below that, obtains current rotation and blends toward the desired quaternion using a fraction clamped to **0.01–1**. |
| `0xbdaa28` | Normalized quaternion interpolation with a near-identical linear branch and sine/acos interpolation branch. No time-delta scaling is visible at its identified caller. |
| `0xbcfac4`–`0xbcfb14` | Checks quaternion finiteness and squared norm between 0.5 and 2 before writing. |
| `0xbdaba0`, `0xbdafa4` | Writes 16 bytes at a validated object plus a cached field offset. The destination field's exact identity remains unresolved. Zucchini does not copy this raw-write mechanism. |

The speed association is supported by decoded `aim_speed` at `0xad6720`, its float store to `0xf9b4e4`, and the synchronization block at `0xad7fa8`–`0xad8050` copying that value to the rotation path's `0xf8546c`.

The supplied game's `Player.SetAimRotation` was also inspected. Its ordinary field-store branch writes four floats, while other branches dispatch through runtime overrides. A successful invocation is not proof the game kept that rotation through its subsequent updates. Zucchini continues to use the named method, not an inferred original field offset.

## Other features inventoried

The following groups are supported by decoded configuration keys in the loader at `0xad6400`–`0xad8000` and related UI paths. They establish configuration presence, not complete or working algorithms.

| Group | Recovered settings/features | Recovery status |
| --- | --- | --- |
| Aim | Enable, FOV circle/radius, speed, distance, bone, priority, trigger, ignore bots/knocked/visibility | Selection and quaternion path traced above; producer layout and all enum meanings incomplete. |
| Additional aim modes | Vectored, humanized/legit, silent, separate legit bone | Labels/configuration identified. Their complete alternate callbacks are not reconstructed. |
| Player visuals | Lines, boxes, health, names, distance, count/count size, skeleton, filters and range | Configuration plus drawing paths observed in the large update function; full rendering behavior not reconstructed. |
| World/item visuals | Vehicles, airdrops, weapons, vests, helmets, medkits | Configuration identified; complete object discovery and rendering paths not reconstructed. |
| Visual colors | Lines, boxes, names, FOV, skeleton, distance, counter, vehicles, airdrops, weapons, vests, helmets, medkits | Separate color keys and color/drawing arithmetic observed. |
| Weapon actions | No recoil, fast swap, fast reload, auto fire | Configuration identified; weapon-swap hook entry also mapped in the earlier binary-difference audit. Other algorithms unresolved. |
| Movement | Teleport, teleport mark, free move, float, spin/spin speed, AI telekill, backjump, speed/speed value | Configuration identified; free-movement and marker-related hook entries mapped previously. Complete algorithms unresolved. |
| Other | Fast medkit, regional blood, force 120 FPS, enemy visibility override, screen stretch, reset guest, instant loot | Configuration identified; medkit/blood/FPS/guest hook entries mapped previously. Runtime effectiveness untested. |

The earlier 12 managed-hook mappings and static fallback checks are in [BINARY-DIFFERENCES.md](BINARY-DIFFERENCES.md). This inventory does not establish that every configuration is exposed, enabled or functional in the supplied version. No additional gameplay feature was added to Zucchini.

## Zucchini changes derived from the comparison

The user reports the IPA launches and moves the view toward enemies, but aiming is inferior to the original. They specifically want aiming whenever enabled, with steadier tracking. This is user-reported device evidence; no device trace or diagnostic export was supplied.

- Native FOV now means a radius in screen points around the game window center, using `Camera.main.WorldToViewportPoint`. The old value meant a full angular cone. Thus **60 now has a different, generally narrower meaning**. Core callers retain an explicit angular compatibility mode.
- The camera position and forward direction now come from that same main camera's transform, so projection and direction calculations share a camera. Camera identity is checked again before applying.
- Zucchini retains a valid target until visibility, life/team eligibility, selected bone, FOV, or scene identity invalidates it. The current target gets priority within the eight-raycast budget. This retention is our requested stability improvement, not a claim that the original has the same lock policy.
- Replaced fixed exponential easing with rate-limited acquisition followed by exact point tracking within each frame's travel allowance. Movement remains bounded at 180 degrees/second. This avoids the previous persistent trailing error for slower moving targets without copying the original's instantaneous high-speed branch.
- Aiming still runs whenever enabled and the playable view is active; it pauses while the menu/share sheet is open, on backgrounding, or when state is invalid. No Speed or Trigger controls were added.
- Diagnostic snapshots identify `stable-screen-v1`, FOV units, the most recent commanded target and angular error.

No claim of exact Monite parity, human indistinguishability, device stability, hit accuracy or detection resistance follows from this static analysis or the synthetic tests. Frame ordering against Unity, game-side overrides, camera modes and real visibility need another iPhone test.

## Local evidence

Full binary material remains outside Git. Relevant paths under `../analysis/`:

- `monite_bindings.py`, `decode_monite_labels.py` — static import/string reconstruction.
- `aiming-research/chained-imports.json`, `decoded-labels.json` — recovered records, including repeated/non-feature labels.
- `aiming-research/main-loop-candidate.asm` and `function-*.asm` — local disassembly supporting the addresses above.
- `aiming-research/game-set-aim.asm` — game method inspection.
- `aiming-research/windows-tests.txt` — portable regression results.

Only this concise analysis and Zucchini's independently written changes are tracked; full proprietary dumps, original protected callbacks, credentials and game archives remain local.
