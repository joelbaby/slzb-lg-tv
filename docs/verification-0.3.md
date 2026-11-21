# v0.3 manual interface verification

Tested on 22 November 2026 (Australia/Perth), using SLZB-MR4U, SLZB-OS v3.4.5.dev1, and an LG GX on Wi-Fi.

## Scope

The optional app page adds individual power, audio, input, app-launch and notification controls, plus a matching Berry call and the shared helper. Browser-free Berry control remains the runtime interface. No new TV permissions are needed.

## Review

Specification and standards reviews compared the implementation with the exact previously tested v0.2 package. The specification review identified a queued-command expiry issue and wrapping of long custom IDs. The expiry correction obtains a coordinator-stamped deadline before queuing each manual command; missing or expired deadlines fail closed. Nineteen Berry checks, five UI checks and installer checks passed. The final package passed installer checks after the live styling correction described below.

## Deployment safeguards

The tested v0.2 ZIP is retained for rollback. Deployment tooling backs up settings and pairing entirely on the coordinator, verifies preservation without printing or downloading credentials, and preserves startup flags. Live native-HTTP tests use a bounded lighting pause with automatic restoration after three minutes or an earlier release. Original script states and lighting source bytes are checked afterward.

## Limits

The interface reports submission, not acknowledged TV state. Physical effects require separate observation. Native HTTP remains shared with other Berry scripts; a busy connection must be left alone. The interface does not pause other scripts or take their HTTP connection.

## Live interface checks

Initial v0.3 installation preserved the saved settings, expanded pairing, startup flags, original script states and lighting source bytes. The production iframe showed Paired with Setup collapsed and all command groups enabled. Submitting an empty volume field triggered native required-field validation. Submitting volume 9 while lighting ran returned the shared-HTTP busy explanation. The matching Berry call was `tv_request("volume", 9)`; the bundled helper contained the saved channels 60 and 61. Both copy buttons selected their text and displayed the manual-copy fallback in the coordinator iframe.

A 390-pixel-wide live check found the referenced coordinator stylesheet returned HTTP 404, leaving controls with browser-default typography and sizing. The final package bundles its own styling. The corrected page was checked at narrow and desktop viewport sizes; at a 390-pixel browser viewport its iframe body measured 330 pixels for both client and scroll width, with no horizontal overflow. The copy button also succeeded through the clipboard API, and the clipboard contained exactly `tv_request("on")`.

## Installed package and TV acceptance

The final v0.3.0 ZIP is 175,912 bytes, SHA-256 `144a0f71bcffc6cbcc0af272d211e9e61520f83745d993861a2ba4ec1756b6c4`. Its installed backend matched the archive exactly. Reinstallation preserved the existing pairing and settings without another TV approval prompt.

Each action was triggered individually through the installed app page. The UI reported submission, and the user separately confirmed the physical effects:

| Control | Test | Observation |
| --- | --- | --- |
| Volume down/up | Down, then up | Both worked |
| Mute/unmute | Mute, then unmute | Both worked |
| Target volume | 10, then 9 | Changed and restored |
| Input | HDMI 2 | Switched successfully |
| App launch | YouTube | Opened successfully |
| Notification | `SLZB UI test` | Appeared on TV |
| Off | Power off | TV turned off |
| On | Wake packet | TV turned back on |

The user confirmed the final TV state: on, volume 9, unmuted. The test window was released early. Restoration reported no errors; all pre-existing script states and startup flags matched the saved baseline, and both lighting source files remained byte-for-byte unchanged. The app was restarted after cleanup. The test browser was closed.

The prior v0.2 report covers browser-free commands. This report verifies the optional manual interface and does not claim automatic HTTP coexistence with lighting scripts that retain the shared connection.
