#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${BERRY_BIN:-}" ]]; then
    revision=9f6fbc97da31881e12391b1c2812bd0b33500c12
    berry="${LG_TV_BUILD_DEPS:-$PWD/.scratch/build-deps}/berry"
    if [[ ! -e "$berry" ]]; then
        mkdir -p "$(dirname "$berry")"
        git clone https://github.com/berry-lang/berry.git "$berry"
        git -C "$berry" checkout --detach "$revision"
    fi
    if [[ "$(git -C "$berry" rev-parse HEAD)" != "$revision" ]] ||
        [[ -n "$(git -C "$berry" status --porcelain --untracked-files=no)" ]]; then
        echo "Expected clean pinned Berry source at $berry ($revision)" >&2
        exit 1
    fi
    make -C "$berry" -j "${BUILD_JOBS:-4}"
    BERRY_BIN="$berry/berry"
fi

"$BERRY_BIN" tests/backend.be
for file in examples/*.be; do
    "$BERRY_BIN" -e "compile('$file', 'file')"
done
