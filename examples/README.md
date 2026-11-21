# Simple Berry examples

Set up and pair the **LG TV** app first, then leave its backend running. Enable **Start on boot** if you want it available after a restart. You can close the browser. Your scripts do not need the TV address, MAC address, or pairing key.

If you originally paired with v0.1, use **Update pairing** in the app to enable the commands beyond power.

## Add TV commands to an existing script

Copy the contents of [power_callbacks.be](power_callbacks.be) into your script once, above the code that uses it. This supplies `tv_request()` and checks results in a timer. `tv_request()` is our example helper, not a built-in Berry function.

Then use **one of these calls** wherever your script needs it:

| What you want | Berry code |
| --- | --- |
| Turn on | `tv_request("on")` |
| Turn off | `tv_request("off")` |
| Set volume to 9 | `tv_request("volume", 9)` |
| Volume up one step | `tv_request("volume_up")` |
| Volume down one step | `tv_request("volume_down")` |
| Mute | `tv_request("mute", true)` |
| Unmute | `tv_request("mute", false)` |
| Switch to HDMI 2 | `tv_request("input", "HDMI_2")` |
| Open YouTube | `tv_request("launch", "youtube.leanback.v4")` |
| Show a message | `tv_request("notify", "The washer has finished")` |

Volume is an integer from 0 to 100. Notifications are short plain text (up to 160 UTF-8 bytes). Input and app IDs depend on the TV; HDMI 2 and the YouTube ID above were tested on an LG GX with those features available.

The helper accepts **one outstanding command at a time**. These examples are alternatives, not a sequence to paste and run together. Wait for `tv_result()` before sending another command. The helper logs the result automatically.

For example, inside an existing button, sensor, or timer callback:

```berry
if !tv_request("notify", "Doorbell")
    SLZB.log("TV request was not queued; the helper may already be busy")
end
```

`true` means the request was queued, not that the TV completed it. This helper does not wait inside your callback. Its result-checking timer must be allowed to run: do not block the script's main flow indefinitely waiting for messages. See [the interface guide](../docs/berry-control.md) if your automation uses a blocking main loop.

## Try one command in a separate script

Copy the complete [power.be](power.be) file into a new SLZB Berry script. Near the top, change only these two lines:

```berry
var action = "volume"
var value = 9
```

Run the script once. It waits for the app's result and writes it to the script log.

Other choices for those two lines:

| Command | `action` | `value` |
| --- | --- | --- |
| On | `"on"` | `nil` |
| Off | `"off"` | `nil` |
| Volume up | `"volume_up"` | `nil` |
| Volume down | `"volume_down"` | `nil` |
| Mute | `"mute"` | `true` |
| Unmute | `"mute"` | `false` |
| HDMI 2 | `"input"` | `"HDMI_2"` |
| YouTube | `"launch"` | `"youtube.leanback.v4"` |
| Notification | `"notify"` | `"Doorbell"` |

Use this waiting example in a standalone script's main flow. For event or timer callbacks, use the first helper instead.

## What the result means

- `submitted`: the app sent the wake packet or submitted the TV command; it cannot confirm the TV's final state.
- `http_busy`: another script is using the shared HTTP client. The command was not sent.
- `permissions_required`: open the app and complete **Update pairing**.
- `not_paired`: complete pairing in the app.
- `unknown`: no matching result arrived in time. Do not assume the command failed or automatically repeat it.

All commands except **On** need the shared HTTP client. If your lighting script keeps it open, these examples will return `http_busy`. Coordinate HTTP ownership before using the TV commands alongside it; do not close another script's connection. [HTTP sharing instructions](../docs/berry-control.md#sharing-http)

Both examples use the app's default channels: command **60**, result **61**, and HTTP lock **62**. If you change the app's channels, update the example's command/result numbers and any cooperating HTTP scripts to match. [Full command reference](../docs/berry-control.md)
