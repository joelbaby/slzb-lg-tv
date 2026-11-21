# LG TV app 0.2: expanded browser-independent commands

## User request

Add volume, mute, input selection, app launching, and notifications, all callable from other Berry scripts with no browser open. Preserve existing On/Off behavior and test the new actions on the user's LG GX after local verification. Use Astra or Sol agents, not Flash. Publishing commits remains pending user approval.

## Public interface

Keep the existing version-1 ISC envelope, correlation ID, expiry, result channel, and cooperative HTTP lock. Add allowlisted actions with a typed `value`: `volume` (integer 0–100), `volume_up`/`volume_down` (no value), `mute` (boolean), `input` (input ID), `launch` (installed app ID), and `notify` (bounded plain text). Reject invalid input before network mutation. Do not expose arbitrary service URIs or credentials to callers. Provide standalone and callback-safe examples.

## Permissions and credential lifecycle

Use only permissions needed by the approved actions. Pairing and runtime registration must agree on granted capabilities. A legacy power-only pairing continues to support On/Off using its original permission manifest. New commands with that key must return a clear upgrade-required result without opening HTTP or triggering an unsolicited TV pairing prompt.

An explicit app-page pairing upgrade may request approval on the TV. Preserve the prior working key on rejection, cancellation, timeout, interrupted save, or failed readback. Verify the new registration before committing it. New capabilities become usable after successful persistence and backend restart. Never broadcast pairing keys, include them in logs/examples/packages, or retain them in browser storage.

## Runtime and compatibility

Commands run on the coordinator's Berry backend, with no browser, Home Assistant, or external command relay. Respect existing native HTTP ownership checks, close only an owned connection, check expiry before the command write, and return honest submission results. The native firmware response/certificate limitations remain unchanged. Other HTTP users must cooperate or the service returns busy.

## Acceptance

- Execute the production Berry backend in tests at the existing public request, credential persistence, and transport seams.
- Verify exact WebSocket requests/payloads, invalid values, escaped text, legacy-key behavior, failed upgrades, successful upgrade/restart, and original On/Off regressions.
- Verify pairing permissions in the TLS fixture and the installable ZIP inventory/constraints/licence notices.
- Review source before installing the updated app on the MR4U. Retain the existing app settings and approved pairing through upgrade.
- Perform explicit permission upgrade on the device if needed, then close all app browser pages.
- Send the new actions from a separate Berry script, physically confirm effects, and restore the user's chosen volume/mute state. Select the user's requested input and app for testing.
- If lighting is paused for exclusive HTTP access, restore its original source, running states, and startup flags in a finally path after each bounded test phase. Do not silently introduce a permanent lighting rewrite.
- Record tested hardware, artifact hash, observed outcomes, remaining limitations, and any unverified behavior. Do not equate `submitted` with TV acceptance.

## Exclusions

TV-state subscriptions, remote-control navigation buttons, picture calibration, arbitrary URI dispatch, permanent lighting handoff changes, and upstream native firmware integration are not part of this extension.
