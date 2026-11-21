# Input and app presets

Checked 22 November 2026. These are common identifiers, not a promise that a given TV has the connector or app. The runtime transport cannot read the installed-app/input inventory, so the page must not present presets as discovered capabilities. Custom IDs remain available.

Live TV (the aerial/cable tuner) launches `com.webos.app.livetv`. The Input menu dispatches this selection as `launch`, and its Berry example uses the same action. HDMI 1–4, AV/Composite (`AV_1`) and Component (`COMP_1`) use the existing `input` action. AV and Component are only relevant on models with those connections.

The app menu includes YouTube (`youtube.leanback.v4`), Netflix (`netflix`), Prime Video (`amazon`), Disney+ (`com.disney.disneyplus-prod`), Apple TV (`com.apple.appletv`), Hulu (`hulu`), and the built-in web browser (`com.webos.app.browser`). Streaming apps must be installed and supported in the TV's region. IDs may vary with model or app generation. These added presets have handler/dispatch coverage, but have not all been physically tested on the owner's TV. The previously verified YouTube and HDMI 2 remain available.

## Sources

- [LG Connect SDK implementation](https://github.com/ConnectSDK/Connect-SDK-Android-Core/blob/master/src/com/connectsdk/service/WebOSTVService.java): explicit YouTube, Netflix and Hulu app IDs.
- [LG ThinQ controller's TV setup guide](https://github.com/lcruy/udi-thinq-py/blob/main/docs/TV-Setup.md): Live TV, Prime Video, Disney+ and Apple TV IDs.
- [Captured webOS input responses](https://github.com/MatKlucznyk/LgWebOs/blob/master/WebSocket%20Requests/commands): `AV_1` and `COMP_1` input identifiers.
- [Glasshouse developer's on-device research](https://rorygallagher2024.github.io/glasshouse/development/TV-RESEARCH/): app/input identifiers and model-specific behavior.
- [LG Application Manager](https://webostv.developer.lge.com/develop/references/application-manager): launching an app requires its ID; a missing app produces an error. Our submission-only transport cannot read that TV error.

## v0.3.1 verification

UI handler tests passed for Live TV dispatching `launch`, AV/Component dispatching `input`, each new app preset, and matching Berry calls. JavaScript syntax and installer checks passed. Installed v0.3.1 on the MR4U; served UI assets matched the package, existing pairing/settings were preserved, and the backend was running without an error. All existing script running/startup settings and both lighting source files were preserved. No TV app launches or input changes were performed as part of this preset-only update, so physical compatibility of the new presets remains unverified.

ZIP: 176,850 bytes, SHA-256 `9a5035bda315ad54c8c45b11e10bdfc98ceff25b7bffaad00e5bc954a35250b5`.
