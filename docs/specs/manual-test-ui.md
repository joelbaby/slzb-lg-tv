# v0.3: optional manual test interface

## Approved design

Extend the existing LG TV app page with individual, user-triggered controls and matching Berry examples. The page is optional for ordinary runtime use; other scripts continue controlling the TV with no browser open. Keep the page small, responsive, and consistent with the coordinator UI. No automatic test sequence.

## Controls

- Power: On and Off.
- Audio: volume down/up, an integer target volume and explicit Set button, separate Mute and Unmute buttons. Do not imply the target value is the current TV volume.
- Input: common HDMI choices and a custom input ID, with an explicit Switch button.
- Apps: a YouTube preset and custom app ID, with an explicit Launch button.
- Notification: short plain text and a Send button.
- Last command/result: describe submission, busy state, invalid input, and uncertain outcome honestly. There is no live TV-state readback.
- Setup: existing configuration, Pair/Update pairing, Forget and advanced channels in an expandable section. Open it initially when setup is incomplete.
- Berry examples: show the equivalent command for the user's chosen control/value, with copying or a usable manual-copy fallback. Explain and provide the shared helper required by `tv_request()`; it is not a built-in function. Mention one pending command at a time and HTTP sharing.

## Behavior

Each click reuses the same validated command execution and HTTP ownership checks as the public Berry interface. Preserve existing ISC callers and pairing permissions. One manual command may be in flight at a time; disable conflicting controls during commands or pairing. Changing a field or selection must not send a command. Reject invalid values before submission, and generate code examples using valid escaping. Never expose pairing keys.

Display paired/backend/setup status only when supported by actual backend responses. Do not show a fake live power, volume, input or mute state. A submitted command is not confirmation of TV state. A busy client must be left alone; the UI must not stop scripts or steal HTTP. Do not retry an unknown outcome automatically.

## Acceptance

Test the actual UI handlers, public backend message handling, generated snippets, validation, pending state, errors/timeouts, and pairing regressions through the existing agreed test seams. Validate the installer format and any new bundled assets.

Review against the exact tested v0.2 source baseline, install on the MR4U while preserving configuration, expanded pairing and app startup settings, and exercise the controls through the real app page. Test the HTTP-busy message while lighting runs; use only a bounded, automatically restored lighting pause for native HTTP commands. Verify narrow-screen layout and readable status/example content. Restore volume to the user's chosen 9 after audio testing. Record observations separately from submitted-command results. Do not commit or push without the user's publishing decision.
