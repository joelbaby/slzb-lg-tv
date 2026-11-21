# Pairing transport investigation

Status: implementation proof in progress. No current release is claimed usable.

## Existing evidence

On the tested coordinator firmware, HTTP upgrades to the LG TV's secure WebSocket endpoint succeed and outgoing WebSocket frames arrive. The HTTP stream reader returns zero bytes after a normal bodyless 101 response. A controlled endpoint that adds a nonstandard response Content-Length makes those same read methods expose frame bytes. This isolates an HTTP body-accounting limitation; it does not establish the exact private firmware implementation.

A fresh registration test supplied a cryptographically random candidate client key. After user approval, the TV returned a different key. A send-only client cannot assume that the TV adopted its chosen credential. The diagnostic credential was discarded and is not used by this app.

## Path being proved

Bundle a pinned MIT BearSSL TLS client as WebAssembly/classic JavaScript in the app page. The app backend owns a bounded TCP connection to the configured TV's fixed control port and carries opaque TLS records between the page and TV. The page implements TLS and WebSocket framing, receives the TV-issued key, and returns it to the app backend for private app-scoped storage. No separate helper, direct browser-to-TV connection, certificate-bypass UI, public relay, or Home Assistant service is needed.

The browser TLS connection is a setup-time pairing transport only. The clarified product requirement is power control from other Berry scripts with no browser open. Runtime power commands therefore need a coordinator-side transport; a browser-dependent Off implementation does not satisfy v1.

## Security boundary

The coordinator management page and its app bridge are trusted. On coordinators accessed over HTTP, page-to-coordinator traffic inherits the management interface's trusted-LAN assumption. Bundled TLS protects the TV-facing leg but does not make the entire operation end-to-end encrypted when the management page uses HTTP. Credentials are temporary in browser memory, never browser persistent storage or logs, and are retained only in the app sandbox. Trust for the TV's self-signed certificate needs an explicit first-use policy and subsequent fingerprint checks.

## Primary sources

- [SLZB HTTP interface](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/http.md)
- [SLZB TCP client](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/tcpclient.md)
- [BeApp bridge and sandbox](https://github.com/smlight-tech/slzb-os-scripts/blob/main/docs/modules/beapp.md)
- [Installer package constraints](https://github.com/smlight-tech/slzb-os-apps/blob/main/README.md)
- [BearSSL buffer-based TLS API](https://bearssl.org/api1.html)
- [Pinned BearSSL source revision](https://bearssl.org/gitweb/?p=BearSSL;a=commit;h=7bea48e5e850ab4cafbe68d3765cdaba13a86d6f)
- [ESP-IDF HTTP read implementation, an explanatory reference rather than the verified SLZB revision](https://github.com/espressif/esp-idf/blob/v5.4.3/components/esp_http_client/esp_http_client.c)
