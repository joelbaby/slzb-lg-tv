# LG TV Control

Control an LG webOS TV **from your SLZB-OS Berry scripts**, even when the browser is closed. Turn it on or off, change the volume, mute or unmute, select an input, open an installed app, or display a notification. The installable app handles pairing and keeps the key on the coordinator.

**Development preview.** The app targets SLZB-MR4U with SLZB-OS v3.4.5.dev1 or later. Power commands and the v0.2 volume, mute, input, app-launch, and notification commands were verified on an LG GX from Berry scripts with the browser closed. Shared HTTP commands were tested with lighting temporarily paused and restored. See [v0.2 hardware verification and limits](docs/verification-0.2.md), [the original power test](docs/verification.md), and the [v0.2 spec](docs/specs/expanded-commands.md).

The v0.3 optional manual controls and Berry-copy interface were also tested on the MR4U, with every TV action physically confirmed. See [v0.3 interface verification](docs/verification-0.3.md).

## Set up your TV

1. Build `dist/lg_tv.zip` as described below or download the `lg-tv-slzb-os` artifact from a successful GitHub Actions run and extract the inner ZIP.
2. Open **Apps** in SLZB-OS and use the local ZIP installer to install `lg_tv.zip`. Start the **LG TV** backend and open its page.
3. Enter your TV's private IPv4 address and Wi-Fi MAC address and save. For wake over Wi-Fi, enable network wake on the TV. The exact name and standby behavior depend on the model and settings.
4. Open the LG TV app in one browser tab while pairing. With the TV on, click **Pair** and select **Yes** when the TV prompts. If you already paired for power control on v0.1, use **Update pairing** to enable the new commands. The app verifies the key on a new connection before saving it.
5. Enable **Start on boot** on the app card to keep Berry control available after coordinator restarts. You can close the browser.

The **On** and **Off** buttons use the same backend as the scripts. **Forget** removes the local pairing. To revoke the pairing on the TV, use the TV's connection settings. To pair a different IP address, forget the old pairing first.

Use **Test your TV** on the app page to try power, audio, input selection, app launch, or notifications individually. A successful submission asks you to check the TV. **Use this in Berry** shows the matching call and a copyable helper configured for your channels. The page can be closed for normal script use.

This is an SLZB-OS app with a Berry backend. It installs through **Apps** and runs separately from firmware integrations such as Hue.

## Call from Berry

Start with the [simple copy-and-paste examples](examples/README.md): one shared helper, then a one-line call for each TV command.

Copy [power.be](examples/power.be) for a one-shot command and set its `action` and `value`. For a timer or device event, copy the functions in [power_callbacks.be](examples/power_callbacks.be) and call, for example, `tv_request("off")`, `tv_request("mute", true)`, or `tv_request("volume", 15)` in your callback.

The defaults are ISC channels **60** for commands, **61** for results, and **62** for cooperative HTTP ownership. Pick distinct, unused channels in the app settings if these conflict with existing scripts, and update your scripts to match.

A `submitted` result reports that the coordinator sent the wake packet or submitted the TV command. Check the TV separately if you need confirmation. See [the Berry interface](docs/berry-control.md) for all actions, other results, and how to share HTTP.

## Shared HTTP requirement

**All commands except On need exclusive or cooperative use of the coordinator's shared HTTP client.** When another script has the client open, or a script holds the configured lock, the app reports `http_busy`. Scripts sharing HTTP must claim the same ISC lock for their transactions and close HTTP before releasing it. On uses Wake-on-LAN and works independently of HTTP.

Run the app on a trusted local network. The pairing page uses TLS to the TV via the coordinator and checks that it sees the same TV certificate on both pairing connections. Initial setup trusts the address you configured. The firmware's native HTTP API used for commands does not verify the TV certificate or expose the upgraded stream's replies, so it cannot tell when the TV rejects a saved key. The saved key is in the app sandbox, away from ordinary app asset downloads. Treat coordinator admin access and other installed Berry scripts as trusted because they may have filesystem access. See [credential storage and transport details](docs/berry-control.md#credentials-and-transport).

## Build and test

Requires Git, GNU Make, Python 3, a C compiler, the Readline development headers (`libreadline-dev` on Ubuntu), Node.js, and OpenSSL. The build fetches pinned BearSSL and Emscripten sources and their licence notices. [Build inputs](vendor/README.md)

```sh
scripts/build-tls.sh
python3 scripts/package.py
scripts/test-berry.sh
node tests/pairing.mjs
node tests/ui.mjs
python3 tests/package_test.py
```

The installer is a flat, stored ZIP with the manifest first and no local settings or credentials. The Berry tests run the production backend against firmware substitutes. The Node test uses a local TLS fixture and a disposable certificate.

MIT licensed. Independent project; not affiliated with, endorsed by, or sponsored by LG Electronics. LG is a trademark of its respective owner. Independent of SMLIGHT.
