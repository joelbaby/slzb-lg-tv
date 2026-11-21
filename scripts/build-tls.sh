#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."

bearssl_revision=7bea48e5e850ab4cafbe68d3765cdaba13a86d6f
emsdk_revision=c0bb220cb6e6f4e0fabb6f6db9efd53390ef5e56
emsdk_version=4.0.23
deps="${LG_TV_BUILD_DEPS:-$PWD/.scratch/build-deps}"
mkdir -p "$deps" dist
deps="$(cd "$deps" && pwd)"
bearssl="${BEARSSL_DIR:-$deps/BearSSL}"
emsdk="${EMSDK_DIR:-$deps/emsdk}"

fetch_revision() {
    local url="$1" target="$2" revision="$3"
    if [[ ! -e "$target" ]]; then
        git clone "$url" "$target"
        git -C "$target" checkout --detach "$revision"
    fi
    if [[ "$(git -C "$target" rev-parse HEAD)" != "$revision" ]] ||
        [[ -n "$(git -C "$target" status --porcelain --untracked-files=no)" ]]; then
        echo "Expected clean pinned source at $target ($revision)" >&2
        exit 1
    fi
}

fetch_revision https://www.bearssl.org/git/BearSSL "$bearssl" "$bearssl_revision"
fetch_revision https://github.com/emscripten-core/emsdk.git "$emsdk" "$emsdk_revision"
bearssl="$(cd "$bearssl" && pwd)"
emsdk="$(cd "$emsdk" && pwd)"
if ! "$emsdk/upstream/emscripten/emcc" --version 2>/dev/null | grep -qF " $emsdk_version"; then
    (cd "$emsdk" && ./emsdk install "$emsdk_version" && ./emsdk activate --embedded "$emsdk_version")
fi

cache="${EM_CACHE:-$deps/emcache}"
# The SDK shell script reads optional variables and is not nounset-safe.
set +u
EMSDK_QUIET=1 source "$emsdk/emsdk_env.sh" >/dev/null
set -u
export EM_CACHE="$cache"
make -C "$bearssl" -j "${BUILD_JOBS:-4}" lib BUILD=build-wasm CC=emcc AR=emar     CFLAGS='-Oz -flto -DBR_USE_URANDOM=0 -DBR_USE_GETENTROPY=0'
exports='["_tls_entropy","_tls_expected_pin","_tls_peer_pin","_tls_websocket_nonce","_tls_websocket_digest","_tls_init","_tls_state","_tls_error","_tls_size","_tls_buffer","_tls_ack"]'
emcc -Oz -flto --no-entry -I"$bearssl/inc" -sMODULARIZE=1 -sEXPORT_NAME=createTls     -sENVIRONMENT=web,node -sFILESYSTEM=0 -sINCOMING_MODULE_JS_API='[]'     -sEXPORTED_FUNCTIONS="$exports" -sEXPORTED_RUNTIME_METHODS='["HEAPU8"]'     -sMALLOC=none -sINITIAL_MEMORY=262144 -sSTACK_SIZE=65536 -sSINGLE_FILE=1     vendor/tls.c "$bearssl/build-wasm/libbearssl.a" -o dist/tls.js
cp "$bearssl/LICENSE.txt" dist/bearssl-license.txt
cp "$emsdk/upstream/emscripten/LICENSE" dist/emscripten-license.txt
cp "$emsdk/upstream/emscripten/system/lib/libc/musl/COPYRIGHT" dist/musl-copyright.txt
