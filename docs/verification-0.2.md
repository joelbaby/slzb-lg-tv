# v0.2 hardware verification

Tested on 22 November 2026 (Australia/Perth) with SLZB-MR4U, SLZB-OS v3.4.5.dev1, and an LG GX on Wi-Fi. Other hardware and firmware have not been verified.

## Package and local validation

The reviewed v0.2.0 ZIP is 158,178 bytes with SHA-256 `ea05d8133a02d335be62137375bd0805744dd4b0595d5ca1ec4cedfdc4af7595`. Its installed Berry backend matched the archive exactly.

Sixteen production Berry checks, example compilation, JavaScript syntax, UI cancellation/lost-save-reply regression, TLS/WebSocket fixture, ZIP inventory/constraint tests, and diff checks passed. Specification and standards reviews identified cancellation during commit, ambiguous storage rollback, and malformed UTF-8 issues; all were corrected and regression-tested before deployment. These are local test results, not a claim that GitHub CI has run for the uncommitted work.

## Installation and permission upgrade

The prior v0.1 package was retained for rollback. Existing settings and the power-only key were backed up and verified entirely on the coordinator. The v0.2 installation preserved the saved data, and a script verified it without downloading or printing credentials. Original application startup settings were restored.

Before permission upgrade, a standalone Berry notification request returned `permissions_required`. Lighting remained running and unchanged. The installed app page displayed **Update pairing**. The user approved the TV prompt, and the app verified and saved the expanded pairing. This was the production app's permission-upgrade flow, not a host pairing helper. The browser tab was then closed; the in-app browser reported no remaining tabs. The backend was stopped and restarted before runtime testing.

## Browser-free runtime tests

All requests came from separate Berry scripts through ISC, with no browser, Home Assistant, or host-to-TV command relay. The scripts reported `submitted`; the user separately confirmed each visible effect.

| Command | Tested value or sequence | Observed outcome |
| --- | --- | --- |
| `volume` | 10, then restoration to 9 | TV volume changed; final level 9 confirmed |
| `volume_down` / `volume_up` | Down then up | Both changes confirmed |
| `mute` | true then false | Mute and unmute confirmed |
| `input` | `HDMI_2` | TV switched to HDMI 2 |
| `launch` | `youtube.leanback.v4` | YouTube opened |
| `notify` | `SLZB LG TV test` | Notification appeared |

The lighting scripts were paused only for each bounded native-HTTP test phase. A `finally` path stopped the test caller/backend, closed HTTP under exclusive test control, restored lighting, and restarted the app. Both restoration phases reported no errors. All 39 pre-existing script entries at the start of this extension test retained their running/idle state and startup flags; this includes the 35 original household/diagnostic entries and four earlier acceptance helpers. Both lighting sources matched their original bytes exactly.

The TV was left in YouTube, unmuted, with volume restored to 9. LG TV v0.2.0 was left running, with Start on boot and Restart on error enabled and no reported backend error. Test scripts are idle with startup disabled. The app's expanded pairing survived the backend restarts between test phases.

## Limits

Every command except Wake-on-LAN uses the shared HTTP client. The existing lighting script retains that client; everyday coexistence still requires cooperative ownership/handoff. These tests used the authorized pause-and-restore procedure and do not establish automatic coexistence with that unmodified script.

Native HTTP still does not expose TV acknowledgements or certificate verification. A `submitted` result alone cannot prove TV acceptance; human observation supplied confirmation here. The power actions had previous live acceptance on v0.1 and passed regression tests in v0.2, but were not physically power-cycled again in this extension test. See [the original power test](verification.md) and [the Berry interface](berry-control.md).
