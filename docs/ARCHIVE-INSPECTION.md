# Nested archive inspection - 2026-09-27

`monite.zip` was inspected without executing its contents. It is a compiled Free Fire application tree, not a folder of menu settings or editable aimbot source. The archive's runtime purpose remains unverified; retain it in distributed test packages.

## Observations

- Compressed archive: 498,191,125 bytes. Expanded entries total 1,479,403,864 bytes, across 3,470 paths (including directories).
- Every nested ZIP entry passed its integrity check. Archive SHA-256: `f591cfde5b02477b1e77c3b388b7c4b26f0a4afcdca1305dc40ff17daff8df64`.
- Its Info.plist identifies Free Fire 1.132.1, build 2019121207, bundle `com.dts.freefireth`, minimum iOS 15.0. The outer supplied package declares minimum iOS 10.0; Zucchini requires iOS 16.0.
- It includes game assets, global metadata, UnityFramework, DataDomeSDK, resources for other bundled SDKs, signing metadata, `FreeFire`, and an additional `FreeFire2` executable. No editable integration source or Monite menu dylib was found inside it.
- ZIP inventory comparison found 3,276 files with matching size and CRC, six differing files, and eight nested-only files. Size/CRC equivalence is an inventory observation, not a cryptographic proof of equality.
- The six differing files are the main executable, UnityFramework, DataDomeSDK, Info.plist, and two signature resource files. Nested-only files are `FreeFire2` and seven `SC_Info` files.
- Global metadata was compared byte-for-byte and is identical. SHA-256: `597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d`.
- The inner and outer Unity binaries share UUID `c8de7371-cba7-3e7a-9e09-30b8e1b89073`, but differ in contents. The outer binary adds `__HOOK_TEXT`, `__HOOK_DATA`, `__MONITE_TEXT`, `__MONITE_DATA`, and `__SAFE_UTF8` sections.
- Byte comparison of corresponding Unity sections found 286 changed bytes in `__TEXT,__text`, 68 in `__TEXT,__stubs`, and 32 in `__TEXT,__objc_stubs`. Other compared file-backed sections match. The meaning of those changes has not been established; they must not be assumed safe or necessary solely from their names.
- The nested main executables declare encryption in their Mach-O headers; they are not suitable for blind replacement of the outer launcher. The outer launcher also has the existing menu library load command. No executables were swapped as part of this inspection.

## What this means for Zucchini

The nested tree resembles a retained game-package copy, but its authenticity, intended purpose, and any runtime extraction behavior are not established. It is useful as a comparison reference for identifying prior binary modifications, confirming metadata consistency, and investigating startup or compatibility failures. It is not a verified pristine vendor baseline.

Replacing the external menu library does **not** remove pre-existing changes inside UnityFramework. The current candidate preserves those game-binary bytes. Their dependency on the original menu implementation and their effect on stability remain unresolved. A successful Zucchini build does not prove compatibility with those modifications.

The immediate implemented improvement is conservative packaging: all bundled resources are retained and every preserved file is SHA-256 checked against the original input. Further functional conclusions require actual device observations; no improved aim performance or anti-cheat behavior was demonstrated by inspecting this archive.

## Local evidence

Full inventories and comparisons remain outside Git:

- `../analysis/monite-archive-inspection.json`
- `../analysis/monite-archive-integrity.json`
- `../analysis/monite-binary-comparison.json`
- `../analysis/monite-engine-section-comparison.json`
- `../analysis/cleanup-package-diff.json`

No game binary, credential, or SDK configuration contents were added to the public repository.
