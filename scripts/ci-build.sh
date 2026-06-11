#!/usr/bin/env bash
#
# ci-build.sh — compile a single template with the correct toolchain.
#
# Usage:   scripts/ci-build.sh <TemplateName>
#
# This is the single source of truth for "how is each template compiled",
# shared by the GitHub Actions workflow (one job per template) and by anyone
# who wants to reproduce a CI build locally on a Mac.
#
# Because the templates are source scaffolding (no committed .xcodeproj), CI
# verifies them at the strongest level achievable without a project file:
#
#   * Swift  -> `swiftc -typecheck` of the app sources against the platform
#               SDK (resolves UIKit/SwiftUI/AppKit/etc. symbols), and a
#               syntax `-parse` of the Tests/ sources (which @testable-import a
#               module that isn't built here).
#   * ObjC   -> `clang -fsyntax-only` per translation unit against the SDK.
#   * ObjC++ -> `clang++ -fsyntax-only` for .mm, plus a real `-c` compile of
#               the pure C++ engine.
#   * Metal  -> real `xcrun metal` shader compile to AIR, plus Swift typecheck.
#   * C/C++  -> a real build AND test run via `make test`.
#
# See docs/CI.md for the rationale and how to extend this.

set -euo pipefail

TEMPLATE="${1:?usage: ci-build.sh <TemplateName>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/templates/$TEMPLATE"

if [[ ! -d "$DIR" ]]; then
    echo "::error::Unknown template '$TEMPLATE' (no directory $DIR)"
    exit 2
fi

cd "$DIR"
echo "==> Building template: $TEMPLATE"
echo "    in $DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# sdk_path <sdk> — echo the SDK path, or empty string if the SDK is absent.
sdk_path() {
    xcrun --sdk "$1" --show-sdk-path 2>/dev/null || true
}

# swift_check <sdk> <target> — typecheck app sources against <sdk>; if the SDK
# is unavailable on this runner, fall back to a syntax-only parse so the job
# still validates the code. Tests/ sources are always parse-only.
swift_check() {
    local sdk="$1" target="$2"
    local app_sources test_sources sdkp
    app_sources=$(find . -name '*.swift' -not -path '*/Tests/*' | sort)
    test_sources=$(find . -path '*/Tests/*' -name '*.swift' | sort)

    if [[ -z "$app_sources" ]]; then
        echo "    (no Swift app sources)"
        return 0
    fi

    sdkp="$(sdk_path "$sdk")"
    if [[ -n "$sdkp" ]]; then
        echo "    swiftc -typecheck (sdk=$sdk target=$target)"
        # shellcheck disable=SC2086
        xcrun --sdk "$sdk" swiftc -typecheck -sdk "$sdkp" \
            -target "$target" -swift-version 6 $app_sources
    else
        echo "::warning::SDK '$sdk' not found on runner; parsing Swift instead of full typecheck"
        # shellcheck disable=SC2086
        swiftc -parse $app_sources
    fi

    if [[ -n "$test_sources" ]]; then
        echo "    swiftc -parse (Tests/)"
        # shellcheck disable=SC2086
        swiftc -parse $test_sources
    fi
}

# objc_syntax <compiler> <lang> <extra-flags...> — run -fsyntax-only over every
# matching source file against the iOS simulator SDK with project headers on
# the include path.
objc_syntax() {
    local cc="$1" lang="$2"; shift 2
    local sdkp includes f
    sdkp="$(sdk_path iphonesimulator)"
    if [[ -z "$sdkp" ]]; then
        echo "::warning::iphonesimulator SDK not found; skipping ObjC syntax check"
        return 0
    fi
    # Add every directory that contains a header to the include path.
    includes=()
    while IFS= read -r d; do includes+=("-I$d"); done \
        < <(find . -name '*.h' -exec dirname {} \; | sort -u)

    local ext
    [[ "$lang" == "objective-c++" ]] && ext="mm" || ext="m"
    while IFS= read -r f; do
        echo "    $cc -fsyntax-only ($lang) $f"
        "$cc" -fsyntax-only -x "$lang" -fobjc-arc -isysroot "$sdkp" \
            -arch arm64 -mios-simulator-version-min=15.0 \
            "${includes[@]}" "$@" "$f"
    done < <(find . -name "*.${ext}" | sort)
}

# ---------------------------------------------------------------------------
# Per-template build recipes
# ---------------------------------------------------------------------------

case "$TEMPLATE" in
    Swift-UIKit)
        swift_check iphonesimulator arm64-apple-ios17.0-simulator
        ;;
    Swift-SwiftUI)
        # Universal app — typecheck against macOS where SwiftUI is always present.
        swift_check macosx arm64-apple-macos14.0
        ;;
    macOS-AppKit)
        swift_check macosx arm64-apple-macos14.0
        ;;
    watchOS-SwiftUI)
        swift_check watchsimulator arm64-apple-watchos10.0-simulator
        ;;
    visionOS-RealityKit)
        swift_check xrsimulator arm64-apple-xros2.0-simulator
        ;;
    Metal)
        swift_check iphonesimulator arm64-apple-ios17.0-simulator
        echo "    compiling Metal shaders -> AIR"
        sdkp="$(sdk_path iphoneos)"
        if [[ -n "$sdkp" ]]; then
            find . -name '*.metal' -print0 | while IFS= read -r -d '' m; do
                echo "    xcrun metal -c $m"
                xcrun -sdk iphoneos metal -I "$(dirname "$m")" -c "$m" \
                    -o "$(basename "$m").air"
            done
        else
            echo "::warning::iphoneos SDK not found; skipping Metal shader compile"
        fi
        ;;
    ObjectiveC-UIKit)
        objc_syntax clang objective-c
        ;;
    ObjectiveCpp-Mixed)
        echo "    compiling pure C++ engine for real"
        find . -name '*.cpp' -print0 | while IFS= read -r -d '' c; do
            echo "    clang++ -std=c++17 -c $c"
            clang++ -std=c++17 -Wall -Wextra -c "$c" -o "$(basename "$c").o"
        done
        objc_syntax clang++ objective-c++ -std=c++17
        ;;
    C-Library)
        make clean
        make test
        ;;
    CPlusPlus-Framework)
        make clean
        make test
        ;;
    *)
        echo "::error::No build recipe for template '$TEMPLATE'"
        exit 2
        ;;
esac

echo "==> OK: $TEMPLATE"
