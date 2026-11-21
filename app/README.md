# LG TV

Control one LG webOS TV from Berry scripts running on this coordinator. Pair here, then close the browser. Scripts can turn the TV on or off, change volume or mute, switch inputs, launch installed apps, and show notifications.

1. Save the TV's IP address and Wi-Fi MAC address.
2. Keep the app open in one tab for pairing. With the TV on, click **Pair** and select **Yes** on the TV.
3. If you paired with an earlier version that only controlled power, click **Update pairing** and approve the new permissions on the TV.
4. Enable **Start on boot** for the app backend so it can receive commands after a coordinator reboot.

Use **Test your TV** to send one command and check its effect on the TV. Open **Use this in Berry** to copy the helper and the equivalent call into your script.

All commands except On require exclusive or cooperative use of the coordinator's shared HTTP client. On uses Wake-on-LAN and requires network wake support on the TV. See the project's [Berry examples](https://github.com/joelbaby/slzb-lg-tv/tree/main/examples) and [setup and shared HTTP requirements](https://github.com/joelbaby/slzb-lg-tv).
