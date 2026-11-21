# Berry TV commands

The LG TV app backend listens for commands from other Berry scripts on the same coordinator. Start it from **Apps** and enable **Start on boot** for unattended use. The app page is needed for initial TV setup and pairing.

For short examples you can copy into your scripts, start with [Simple Berry examples](../examples/README.md). The details below describe the underlying protocol.

The optional **Test your TV** panel sends the same commands through the app backend. Open **Use this in Berry** to copy the call for the last command you chose and the helper configured for your channels. A browser test exercises the TV connection and shared HTTP checks. Run a Berry script separately to verify that it can send requests on the configured ISC channels.

## Message format

Use the same channels shown in the app's **Berry script channels** settings. The defaults are command 60, result 61, and HTTP lock 62. Each must be distinct and within 0–100. Reserve the command channel for LG TV requests, since any script reading that queue can consume a message.

1. Claim the command channel with `ISC.CH_TYPE_PUBLIC` and subscribe to the result channel before sending.
2. Send a JSON string with `v: 1`, an `action` from the table below, its `value` where needed, a unique `id`, and an integer `expires`. The ID is 1–48 characters using letters, digits, hyphens, or underscores. Set `expires = (SLZB.millis() + 15000) & 0x7fffffff`. Use a fresh ID on every command.
3. Check `ISC.send()`. A false return means the command queue did not accept the request.
4. Read the result JSON on the result channel. Match the `id` to the original command, since every subscriber gets a copy of each result. Wait at most 17 seconds in a standalone script.
5. For a timer or device event callback, enqueue only and check the result in a later callback with `ISC.receive(channel, 0)`. Blocking receive in a callback stalls callbacks across the coordinator.

The app rejects expired or too far future requests before executing them and remembers recent IDs while the backend runs. Duplicate requests within that window do not repeat commands. The app checks expiry again between native HTTP registration and the command frame. A caller timeout cannot interrupt a firmware network call.

Examples for the default channels are in [the examples directory](../examples).

| Action | Value | Effect |
| --- | --- | --- |
| `on` | Omit | Send a Wake-on-LAN packet. |
| `off` | Omit | Request TV standby. |
| `volume` | Integer 0–100 | Set the volume. |
| `volume_up`, `volume_down` | Omit | Change the volume one step. |
| `mute` | Boolean `true` or `false` | Mute or unmute. |
| `input` | A TV input ID such as `"HDMI_2"` | Switch to that input. |
| `launch` | An installed app ID such as `"youtube.leanback.v4"` | Open that app. |
| `notify` | Plain text, 1–160 UTF-8 bytes without ASCII control characters | Show a brief message on the TV. |

Input and app IDs can contain 1–96 ASCII letters, digits, underscores, periods, or hyphens. IDs depend on the TV model, firmware, and installed apps. The YouTube example comes from [LG's Connect SDK](https://github.com/ConnectSDK/Connect-SDK-Android-Core/blob/master/src/com/connectsdk/service/WebOSTVService.java#L497-L523). The app sends known commands without enumerating inputs or apps. [webOS client request formats](https://github.com/bendavid/aiopylgtv/blob/master/aiopylgtv/webos_client.py)

With a power-only pairing from v0.1, open the app in one tab, click **Update pairing**, and approve the new permissions on the TV. The app verifies the new key on a second connection before saving it. You can cancel up to the start of the save. The local power-only key is retained through the upgrade. If the app cannot confirm which pairing was saved, reopen the page to check. The TV controls whether its previously issued key remains valid. The requested permissions cover power, audio, input selection, launching apps, and toast notifications. [LG Connect SDK permission definitions](https://github.com/ConnectSDK/Connect-SDK-Android-Core/blob/master/src/com/connectsdk/service/webos/WebOSTVDeviceService.java#L134-L159)

| Result | Meaning |
| --- | --- |
| `submitted` | The wake packet was sent or the command frames were submitted. Check TV state separately. |
| `http_busy` | Another script holds the configured HTTP lock or has the shared client open. |
| `not_configured`, `not_paired` | Set up the TV or complete pairing in the app. |
| `permissions_required` | Use **Update pairing** on the app page to enable the new commands. |
| `pairing_busy` | A pairing session is in progress. |
| `transport_failed`, `upgrade_failed` | The coordinator encountered a transport error, or the TV did not return an HTTP 101 upgrade. |
| `expired`, `duplicate`, `invalid_request`, `queue_busy` | This request did not start another command. |
| No result | Check that the app is running, its channels match, and result queues have room. The action outcome is unknown. |

## Sharing HTTP

Firmware scripts all share one `HTTP` client. All TV commands except On use that client. Have every HTTP user on the coordinator follow the same ownership protocol. The HTTP lock channel is a private ISC claim used for mutual exclusion. It needs no messages.

1. Call `ISC.claim(lock_channel, ISC.CH_TYPE_PRIVATE)` before opening or modifying HTTP. If the claim fails, defer the transaction.
2. Once you hold the claim, call `HTTP.isOpened()`. If the client is already open, release the claim and defer the transaction. A client may still be open after an earlier forced stop.
3. Use HTTP for one bounded transaction. Call `HTTP.close()` on each exit if your script opened the client, then call `ISC.release(lock_channel)`.
4. Keep HTTP off timer/event callbacks that would block other scripts. Do the networking in the script's main flow.

The guard detects an existing open client. It cannot prevent a script that ignores the lock from changing the shared client concurrently. For a safe deployment use sole ownership or coordinate all HTTP users. Close and release between transactions to let the TV app use HTTP.

## Credentials and transport

Open the LG TV app page in a single browser tab for pairing. Firmware sends page-close events without a tab ID. Closing any copy of the app page during setup cancels the active pairing to free the TV connection.

Pairing uses the app page's bundled TLS client through a Berry TCP connection fixed to the configured TV address and port 3001. The TV issues a key after approval. The app page verifies registration on another TLS connection using the saved fingerprint from the first connection, then hands the key to the backend. The coordinator keeps it in an app-scoped hidden file. The page keeps no persistent copy. Key material is excluded from app replies, logs, packages, and ISC messages.

An SLZB-OS HTTP management session does not encrypt the app bridge traffic. Use it on a trusted LAN and protect coordinator management access. The hidden file is not served as a normal app asset, but privileged filesystem access, including the coordinator's general file API or unrestricted scripts, may read it.

Runtime commands except On use native HTTPS with the saved key. Firmware doesn't verify the TV certificate through this API, so the setup fingerprint applies to browser-assisted pairing only. The firmware handles the native network timeout, and the upgraded stream API returns neither a write byte count nor the TV's normal registration and command replies. Treat `submitted` as a send result. This transport cannot detect when the TV declines registration with a saved key. If you revoke the app on the TV, Forget and Pair again. Native WebSocket nonce and mask bytes use Berry's `math.rand()` because the installed scripting API exposes no cryptographic random binding. The browser TLS implementation uses the browser's secure random source.

See the published [ISC reference](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/isc.md), [WOL reference](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/wol.md), and [HTTP reference](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/http.md).
