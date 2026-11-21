# Pairing TLS build inputs

`tls.c` is the app's C wrapper for BearSSL's TLS 1.2 client. It compiles to WebAssembly embedded in `dist/tls.js` so the app can load it in a sandboxed iframe without a separate WASM fetch.

- [BearSSL](https://www.bearssl.org/gitweb/?p=BearSSL;a=commit;h=7bea48e5e850ab4cafbe68d3765cdaba13a86d6f) at commit `7bea48e5e850ab4cafbe68d3765cdaba13a86d6f`. Its MIT licence is included with the installer.
- [Emscripten SDK](https://github.com/emscripten-core/emsdk/tree/c0bb220cb6e6f4e0fabb6f6db9efd53390ef5e56) at commit `c0bb220cb6e6f4e0fabb6f6db9efd53390ef5e56`, toolchain 4.0.23. The installer includes the Emscripten runtime licence and the [musl libc copyright notice](https://github.com/emscripten-core/emscripten/blob/4.0.23/system/lib/libc/musl/COPYRIGHT) for the C library bundled with the toolchain.

Run `scripts/build-tls.sh` from the checkout. The dependency source and toolchain cache default to `.scratch/build-deps/`. You can reuse existing pinned checkouts with `BEARSSL_DIR` and `EMSDK_DIR`. The Berry test runner pins upstream Berry separately and supports `BERRY_BIN` for a locally built interpreter.
