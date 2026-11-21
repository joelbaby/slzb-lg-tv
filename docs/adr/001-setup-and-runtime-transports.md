# Setup and runtime transports

Status: accepted for implementation, pending browser-free hardware acceptance.

## Requirement

Users install the open-source app, pair through its page by accepting the TV prompt, and then invoke On or Off from their own Berry scripts with no browser open. Pairing credentials remain in the app backend after setup. The app must not publish the key to browser event subscribers or calling scripts.

## Decision

Use the proven app-contained browser TLS client and Berry TCP bridge only for initial pairing. Store the returned credential in an app dotfile, with the existing coordinator-management access boundary documented. Use an always-running Berry backend for ordinary commands. Other scripts communicate through configurable ISC request and result channels. On invokes WOL. Off uses the native HTTP secure WebSocket write path with the stored key.

The app is an independently installable extension. We found documentation for built-in integration modules but no public mechanism for adding a new native integration to the existing firmware. A future SMLIGHT-supported native LG integration or independent TLS binding could replace the runtime adapter without changing the caller protocol.

## Constraints

The native HTTP object is shared. Off requires sole ownership or cooperation from every other HTTP user through a configured ISC lock. It must return busy without changing an already-open client. It must not stop other automations, steal the client, or close an unowned connection. The test household lighting script retains the client, so initial live tests require an explicitly bounded pause and restoration; this is a test procedure, not a production solution for concurrency.

The installed firmware does not expose the WebSocket response frames after a normal bodyless 101. Therefore a successful native submission is not proof that the TV accepted the credential or powered off. Native HTTPS does not expose certificate validation here; the pairing-time certificate pin cannot protect native runtime requests. The app must document these firmware limitations and trusted-LAN assumptions rather than claim acknowledgement or end-to-end certificate validation.

## Release evidence

Pair → Yes and a second authenticated TLS registration have passed in the prototype. Production package tests and Berry-script On/Off with every browser page closed remain required, including backend restart, busy-client preservation, and restoration of unrelated scripts. See the [runtime investigation](../research/berry-runtime.md) and [approved specification](../specs/v1.md).
