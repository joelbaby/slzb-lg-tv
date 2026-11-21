# Verification of the development preview

The reviewed v0.1.0 installer was installed on an SLZB-MR4U running SLZB-OS v3.4.5.dev1 and tested with an LG GX using Wi-Fi on 22 November 2026 (Australia/Perth). Other models and firmware versions have not been verified.

## Local tests and review

The production Berry backend passed tests executed with the host Berry interpreter and firmware substitutes. Coverage includes independent ISC commands, configuration and pairing across restart, invalid/expired/duplicate requests, shared HTTP contention, owned-client cleanup, and pairing lifecycle. Failed settings writes and readbacks preserve the previous committed configuration across restart. The TLS/WebSocket fixture and ZIP format/content checks passed. The package includes pinned BearSSL, Emscripten, and musl notices. Separate specification and standards reviews identified persistence and licence-notice issues; both were corrected and the relevant tests passed before installation.

## Hardware acceptance

- The app was installed with the local ZIP installer API. Its installed Berry backend matched the reviewed archive exactly.
- The pairing already approved in the app prototype was copied between app folders by a temporary script entirely on the coordinator, then read back and compared there. No pairing key was downloaded, logged, or included in a package. The production app page did not undergo a fresh live Pair in this acceptance run; real Pair → Yes evidence comes from the preceding transport prototype, and the production pairing path has fixture coverage.
- The app backend was stopped and restarted before runtime testing, loading the saved configuration and key from device storage.
- All in-app browser tabs were closed. Separate one-shot Berry scripts sent ISC commands, without a browser, Home Assistant, or host-based TV-command relay.
- With the original lighting script running and retaining its HTTP connection, Off returned `http_busy`. The lighting source and original script states were unchanged.
- Both lighting scripts were temporarily paused, the retained HTTP connection was closed under exclusive test control, and the Berry caller requested Off. The app returned `submitted`; the user separately confirmed the TV physically turned off.
- A `finally` restoration path stopped the test command/backend, cleaned up HTTP under exclusive test control, and restored lighting. No restoration errors occurred. The app backend was then restarted.
- With lighting running, the separate Berry caller requested On. The app returned `submitted`; the user separately confirmed the TV turned on.
- All 35 pre-existing scripts retained their original running/idle states and startup flags. Both lighting scripts' source bytes matched their pre-test snapshots exactly.
- The LG TV backend was left running with Start on boot and Restart on error enabled. Test callers are idle with startup disabled. The TV was left on.

## Limits

The original lighting script retains the shared HTTP client. Off will return `http_busy` during ordinary operation until HTTP users adopt a cooperative ownership/handoff policy. The temporary pause used for acceptance is not an automatic production integration. On does not use HTTP and was verified alongside lighting.

The native Off API does not expose the TV acknowledgement or certificate verification. `submitted` is not a confirmed power-state result; physical observation supplied the confirmation in this test. Native network timeouts are controlled by firmware. See [the runtime interface](berry-control.md) for operational and trust boundaries.

## Tested artifact

- ZIP size: 152,185 bytes
- SHA-256: `a1a374d070655eaa4b1eb97035fb2b987cdb2b4154d8db9167853ea89e35c3e1`

The archive hash identifies the deployed artifact independently of later documentation edits.
