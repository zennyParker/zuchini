#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
OUT="$ROOT/build/native"
mkdir -p "$OUT"
COMMON=(-target arm64-apple-ios16.0 -sdk "$SDK" -O -swift-version 5)
xcrun swiftc "${COMMON[@]}" -emit-module -emit-library -static -module-name ZuchiniCore Sources/ZuchiniCore/*.swift -emit-module-path "$OUT/ZuchiniCore.swiftmodule" -o "$OUT/libZuchiniCore.a"
xcrun swiftc "${COMMON[@]}" -emit-module -emit-library -static -module-name ZuchiniMenu Sources/ZuchiniMenu/*.swift -I "$OUT" -emit-module-path "$OUT/ZuchiniMenu.swiftmodule" -o "$OUT/libZuchiniMenu.a"
xcrun clang++ -target arm64-apple-ios16.0 -isysroot "$SDK" -fobjc-arc -std=c++17 -O2 -c Native/RuntimeBridge.mm -o "$OUT/RuntimeBridge.o"
xcrun swiftc "${COMMON[@]}" -emit-library -module-name ZucchiniInjected -I "$OUT" -L "$OUT" -lZuchiniMenu -lZuchiniCore -lc++ -import-objc-header Native/RuntimeBridge.h Native/InjectedEntry.swift "$OUT/RuntimeBridge.o" -framework UIKit -framework Foundation -framework SwiftUI -framework QuartzCore -Xlinker -install_name -Xlinker '@executable_path/Frameworks/Monite.dylib' -o "$OUT/Monite.dylib"
codesign --force --sign - "$OUT/Monite.dylib"
xcrun otool -L "$OUT/Monite.dylib" > "$OUT/dependencies.txt"
shasum -a 256 "$OUT/Monite.dylib" > "$OUT/SHA256.txt"
