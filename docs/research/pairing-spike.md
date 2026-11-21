# Browser TLS pairing spike

The v3.4.5.dev1 SLZB-MR4U ran a WebAssembly TLS 1.2 client inside its installed app iframe. The client received a delayed, fragmented WebSocket registration result through the BeApp bridge and a Berry-owned TCP connection. It saved a synthetic key, re-registered with it in a new TLS session, and received acknowledgement of a fixture command. On the real LG GX, Pair then Yes on the TV produced a registration that the app saved on the coordinator and verified on a new socket. Browser TLS provided the response path that native HTTP stream mode lacked after a bodyless HTTP 101.

## Build and package

| Item | Bytes |
| --- | ---: |
| BearSSL WebAssembly | 81,088 |
| Single-file classic JavaScript, including WebAssembly | 96,840 |
| Installed fixture ZIP | 127,091 |
| Installed live-TV probe ZIP | 128,378 |
| Firmware installer limit | 500,000 |

The prototype used [BearSSL commit 7bea48e](https://www.bearssl.org/gitweb/?p=BearSSL;a=commit;h=7bea48e5e850ab4cafbe68d3765cdaba13a86d6f) and [Emscripten SDK 4.0.23](https://github.com/emscripten-core/emsdk/tree/4.0.23). Emscripten linked the TLS 1.2 client with size optimization and link-time optimization. The bundle embeds WebAssembly and loads as a classic script, so instantiation does not need a cross-origin WebAssembly fetch. The ZIP stored all files at its root, with `meta.json` first. It includes the BearSSL, Emscripten and project licence notices. [SLZB-OS installer format](https://github.com/smlight-tech/slzb-os-apps/blob/243848922291dff483cce20a2699c1c4ed821f22/README.md#device-constraints-checked-by-ci)

## What passed

- The Node fixture used an independently generated self-signed RSA certificate and negotiated TLS 1.2 with ECDHE-RSA-AES128-GCM-SHA256. Node's X.509 fingerprint matched the SHA-256 leaf fingerprint computed by the client. A subsequent client rejected a mismatched pin during the TLS handshake.
- The fixture split the bodyless 101 across TLS writes. The client validated the WebSocket accept header, masked its frames, ignored a registration result with an unrelated ID, and processed a ping interleaved with the fragments of the delayed matching registration result. Node limited reads to 37 bytes per transport exchange.
- The installed app used the coordinator's sandboxed iframe and its SDK. It reported successful WASM instantiation and browser `crypto.getRandomValues()`. In that iframe, clicking Pair ran the same protocol against the fixture over the real BeApp event bridge and Berry `TCP_CLIENT`. The backend persisted the synthetic registration and checked readback. Clicking Check saved registration opened a new TLS session and received the fixture's authenticated command acknowledgement.
- The bridge bound one active socket to an installation-specific local address and port 3001, with 256-byte chunks, a session ID, sequential request/reply, and a session deadline. It closed on normal completion. Disconnect and timeout paths are implemented in the spike. Maximum bridge payload, forced queue exhaustion, cancellation under congestion, and timeouts under client loss remain unmeasured.
- A comparison of the 35 unrelated coordinator scripts before and after the fixture and live pairing showed the same inventory, sizes, running states and boot flags. The probe uses its own TCP socket and does not use the shared native HTTP client.

## Replay commands

The untracked development sources and local build cache are under `.scratch/pairing-spike/` in the development checkout. These commands reproduce the spike from those sources. A clean checkout contains this report and needs the prototype source or a later implementation before replay.

```bash
cd .scratch/pairing-spike
git clone https://www.bearssl.org/git/BearSSL BearSSL
git -C BearSSL checkout 7bea48e5e850ab4cafbe68d3765cdaba13a86d6f
git clone --depth 1 --branch 4.0.23 https://github.com/emscripten-core/emsdk.git emsdk
(cd emsdk && ./emsdk install 4.0.23 && ./emsdk activate --embedded 4.0.23)
bash build.sh
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 2 \
  -subj /CN=pairing-spike-fixture -keyout fixture-key.pem -out fixture-cert.pem
node fixture-test.mjs
```

For the installed fixture, provide private addresses through the environment. The fixture listens on the workstation address, accepts the specified coordinator peer, and stops when the foreground command ends. The ZIP and the fixture key are temporary local artifacts. Keep them and their local addressing out of source control.

```bash
node fixture.mjs serve "$FIXTURE_ADDRESS" "$COORDINATOR_ADDRESS"
```

From a second shell in the spike directory, build, then install on the coordinator as a local app. Start its backend and open its app page. Click Pair, then Check saved registration. Stop the fixture and probe backend when done.

```bash
python3 pack.py --fixture "$FIXTURE_ADDRESS"
```

## Credential boundary

The observed firmware serves ordinary app data files over its app asset route even without developer mode. A synthetic dotfile written by Berry was unavailable on that route. The coordinator's general management file API still returned that marker. This test device's management UI had no configured authentication, so app sandbox storage is not separate from access to coordinator management. The SDK's credential handoff also traverses the HTTP management connection. The probe made no management authentication changes. [BeApp sandbox and messaging APIs](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/beapp.md)

Firmware app events are delivered over the management WebSocket. The host UI filters events by app when forwarding to the iframe. A production implementation should keep the registration key out of those events. The live probe submits a new key only from the iframe to the backend, retains it inside an app dotfile, and replies with status. First-use certificate trust depends on the local network. Later sessions can reject a changed leaf certificate. The SDK's `call()` routes to a firmware endpoint with no supported Berry handler on this build. The documented `sendMessage()` acknowledges submission and `BEAPP.send()` provides asynchronous replies. The live probe uses the browser's transient original key to verify new registration on a second socket.

## Published app patterns

The five apps in the SMLIGHT catalog revision reviewed here all use `BeApp.sendMessage()` and `BeApp.onMessage()` with `BEAPP.receive()` and `BEAPP.send()`. The three that persist configuration use ordinary JSON files via `FS.open()`. The reviewed code stores Zigbee timers, sniffer settings, and parser settings or address lists. It provides no precedent for a reusable credential vault or a private request/reply channel. This is an inventory of the published catalog and a limited search for public SLZB Berry apps. [Catalog revision](https://github.com/smlight-tech/slzb-os-apps/blob/243848922291dff483cce20a2699c1c4ed821f22/apps.json) · [Zigbee timers storage](https://github.com/smlight-tech/slzb-os-apps/blob/243848922291dff483cce20a2699c1c4ed821f22/apps/zhb_timers/app.be#L45-L79) · [Sniffer settings](https://github.com/smlight-tech/slzb-os-apps/blob/243848922291dff483cce20a2699c1c4ed821f22/apps/zb_sniffer/app.be#L181-L207) · [Parser settings and address lists](https://github.com/smlight-tech/slzb-os-apps/blob/243848922291dff483cce20a2699c1c4ed821f22/apps/ztoe_parser/app.be#L106-L184)

The firmware's built-in Hue integration has a separate settings mechanism. The installed UI bundle declares the Hue API key as a password setting, displays only whether the key is set in its edit form, and submits a replacement through the integrations management API. The documented `HUE.setup()` accepts a Hue-specific session override, and the other documented methods operate on the Hue Bridge. Neither the integration reference nor the BeApp reference documents using that store for app-defined secrets. This finding comes from public documentation and static UI code. No configured integration value was requested. [Hue Berry module](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/hue.md) · [BeApp reference](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/beapp.md)

## Real-TV attempt

The first live Pair reached the LG GX approval prompt and closed at its 60-second deadline before approval was received. On a fresh attempt the user pressed Yes on the TV. The app received the matching registration, sent the new key only to its Berry backend, and the backend confirmed its app dotfile write by reading back the key and certificate fingerprint. The app opened a second socket, validated the same certificate fingerprint, confirmed the TV accepted the key again, and closed the socket. The UI reported success and released its transient browser copy. It did not write to browser storage, transmit the saved key in an outbound app event, or send a power command.

This establishes Pair and persistence readback on the installed MR4U and tested TV. The fixture listener was stopped. The temporary app remains installed with its backend stopped and its boot and restart options disabled.

## Off transport decision

The browser TLS transport can read a command acknowledgement when it has a key, as the fixture demonstrated. The observed host blocks general and app file routes in `BeApp.api()`. It also has no supported synchronous handler for `BeApp.call()`. The documented `WEBSERVER` hook is a separate coordinator-wide endpoint and falls outside the app SDK's same-origin API bridge. The spike did not add an endpoint or send a real persisted key through the app event stream. [BeApp reference](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/beapp.md) · [WEBSERVER API](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/webserver.md)

Native HTTP Off can retain the key on the backend, but the HTTP client is shared across scripts and its public API does not establish exclusive ownership. A generic app must preserve unrelated clients. A private request/reply binding or an independent native WSS client would remove the remaining trade-off. The live spike does not send power commands. [Native HTTP API](https://github.com/smlight-tech/slzb-os-scripts/blob/f4cae87c9f89282883061ba80b114e83cf9ffc0d/docs/modules/http.md)
