/* SPDX-License-Identifier: MIT */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const pin = "12".repeat(32);
const elements = new Map();
function element(id) {
    if (!elements.has(id)) {
        elements.set(id, {
            handlers: {},
            addEventListener(event, handler) { this.handlers[event] = handler; },
            focus() { this.focused = true; },
            select() { this.selected = true; }
        });
    }
    return elements.get(id);
}

let receive;
let expanded = false;
const sent = [];
const commands = [];
let result = "submitted";
let deadline = 16000;
const timers = new Map();
let nextTimer = 0;
let nextSession = 0;
const BeApp = {
    ready: async () => ({folder: "lg_tv"}),
    onMessage(callback) { receive = callback; },
    async sendMessage({cmd, sid, ...fields}) {
        sent.push(cmd);
        const send = fields => queueMicrotask(() => receive(JSON.stringify({sid, ...fields})));
        if (cmd === "status") {
            send({op: "status", paired: true, expanded, channelsReady: true, config: {
                host: "10.0.0.25", mac: "02:00:00:00:00:25", request: 12, result: 34, lock: 62
            }});
        }
        if (cmd === "upgrade" || cmd === "reopen") send({op: "open", host: "10.0.0.25", pin});
        // Commit on the device but drop the reply, like a broken app bridge.
        if (cmd === "save") expanded = true;
        if (cmd === "prepare_test") send({op: "prepare_test", expires: deadline});
        if (cmd === "test") {
            commands.push({sid, ...fields});
            if (result) send({op: "test", status: result});
        }
    }
};

const uiSource = readFileSync(new URL("../app/ui.js", import.meta.url), "utf8");
const clipboard = {};
const loadPage = () => runInNewContext(uiSource, {
    BeApp, AbortController,
    TextEncoder, navigator: clipboard,
    LgBerryExample: readFileSync(new URL("../examples/power_callbacks.be", import.meta.url), "utf8"),
    document: {getElementById: element},
    window: {addEventListener() {}},
    createTls: async () => ({}),
    LgPairProtocol: {
        hex: () => (++nextSession).toString(16).padStart(32, "0"),
        random: () => new Uint8Array(16),
        TlsStream: class { constructor(_tls, _exchange, savedPin) { this.pin = savedPin; } },
        WebSocketStream: class { async connect() {} },
        register: async (_socket, _showPrompt, key) => key ?? "fixture-key"
    },
    setTimeout(handler, delay) {
        const id = ++nextTimer;
        timers.set(id, {handler, delay});
        return id;
    },
    clearTimeout(id) { timers.delete(id); }
});

const settle = () => new Promise(resolve => setImmediate(resolve));
loadPage();
await settle();
assert.equal(element("pair").textContent, "Update pairing");
assert.equal(element("setup").open, true);
assert.equal(element("audio-controls").disabled, true);
assert.equal(element("off").disabled, false);
element("pair").handlers.click();
await settle();
assert(sent.includes("save"));
assert.equal(element("cancel").hidden, true);
assert.match(element("status").textContent, /Saving pairing/);
element("cancel").handlers.click();
await settle();
assert(!sent.includes("close"));
assert(![...timers.values()].some(timer => timer.delay === 85000));
assert.equal(timers.size, 1);
const [saveReplyTimer] = timers.values();
assert.equal(saveReplyTimer.delay, 5000);
saveReplyTimer.handler();
await settle();
assert.match(element("status").textContent, /could not confirm.*reopen/i);
assert.doesNotMatch(element("status").textContent, /cancelled/i);
assert.equal(expanded, true);
console.log("PASS pairing commit ignores Cancel and reports a lost reply as uncertain");

elements.clear();
loadPage();
await settle();
assert.equal(element("setup").open, false);
assert.equal(element("audio-controls").disabled, false);

const submit = id => element(id).handlers.submit({preventDefault() {}});
const click = id => element(id).handlers.click();
const takeCommand = (action, value) => {
    const {sid, ...fields} = commands.shift();
    assert.match(sid, /^[a-f0-9]{32}$/);
    assert.equal(fields.expires, deadline);
    assert.equal(fields.action, action);
    if (value === undefined) assert(!Object.hasOwn(fields, "value"));
    else assert.equal(fields.value, value);
};

for (const [button, action, value] of [
    ["on", "on"], ["off", "off"], ["volume-up", "volume_up"],
    ["volume-down", "volume_down"], ["mute", "mute", true], ["unmute", "mute", false]
]) {
    click(button);
    await settle();
    takeCommand(action, value);
    assert.match(element("test-result").textContent, /Check your TV/);
}

element("volume").valueAsNumber = 9;
await settle();
assert.equal(commands.length, 0);
submit("volume-form");
await settle();
takeCommand("volume", 9);
assert.equal(element("berry-call").value, 'tv_request("volume", 9)');

for (const [action, preset, custom] of [
    ["input", "HDMI_2", "HDMI_4"], ["launch", "youtube.leanback.v4", "com.example.player"]
]) {
    element(`${action}-preset`).value = preset;
    element(`${action}-preset`).handlers.change();
    assert.equal(commands.length, 0);
    submit(`${action}-form`);
    await settle();
    takeCommand(action, preset);

    element(`${action}-preset`).value = "custom";
    element(`${action}-preset`).handlers.change();
    assert.equal(element(`${action}-custom-field`).hidden, false);
    element(`${action}-custom`).value = custom;
    assert.equal(commands.length, 0);
    submit(`${action}-form`);
    await settle();
    takeCommand(action, custom);
}

for (const [id, action] of [["com.webos.app.livetv", "launch"], ["AV_1", "input"], ["COMP_1", "input"]]) {
    element("input-preset").value = id;
    element("input-preset").handlers.change();
    assert.equal(commands.length, 0);
    submit("input-form");
    await settle();
    takeCommand(action, id);
    assert.equal(element("berry-call").value, `tv_request("${action}", "${id}")`);
}
for (const id of ["netflix", "amazon", "com.disney.disneyplus-prod", "com.apple.appletv", "hulu", "com.webos.app.browser"]) {
    element("launch-preset").value = id;
    submit("launch-form");
    await settle();
    takeCommand("launch", id);
}
// Return to custom input validation for the checks below.
element("input-preset").value = "custom";

const notification = 'Café "ready" \\ 📺';
element("notification").value = notification;
submit("notify-form");
await settle();
takeCommand("notify", notification);
const snippet = 'tv_request("notify", "Café \\"ready\\" \\\\ 📺")';
assert.equal(element("berry-call").value, snippet);
console.log("PASS manual controls send matching commands only after an explicit action");

for (const badVolume of [NaN, 9.5, 101]) {
    element("volume").valueAsNumber = badVolume;
    submit("volume-form");
    assert.match(element("test-result").textContent, /whole number/);
}
element("input-custom").value = "wrong input";
submit("input-form");
assert.match(element("test-result").textContent, /Enter an ID/);
for (const invalid of ["", "📺".repeat(41), "Hi\uD800", "Bad\x01"]) {
    element("notification").value = invalid;
    submit("notify-form");
    assert.match(element("test-result").textContent, /UTF-8 bytes/);
}
assert.equal(commands.length, 0);
assert.equal(element("berry-call").value, snippet);
console.log("PASS invalid values stay on the page and do not become Berry calls");

assert.match(element("berry-helper").value, /^var command_channel = 12$/m);
assert.match(element("berry-helper").value, /^var result_channel = 34$/m);
await click("copy-call");
assert.equal(element("berry-call").focused, true);
assert.equal(element("berry-call").selected, true);
assert.match(element("copy-status").textContent, /Text selected/);
let copied;
clipboard.clipboard = {writeText: async value => { copied = value; }};
await click("copy-helper");
assert.equal(copied, element("berry-helper").value);
assert.match(element("copy-status").textContent, /Copied/);
console.log("PASS matching Berry code uses configured channels and supports manual copying");

deadline = undefined;
click("on");
await settle();
assert.equal(commands.length, 0);
assert.match(element("test-result").textContent, /did not supply a command deadline/);
deadline = 16000;

result = null;
click("mute");
assert.equal(element("audio-controls").disabled, true);
assert.equal(element("settings-fields").disabled, true);
click("on");
await settle();
const [{sid}] = commands;
receive(JSON.stringify({sid: "wrong-session", op: "test", status: "submitted"}));
await settle();
assert.equal(commands.length, 1);
assert.match(element("test-result").textContent, /Sending/);
receive(JSON.stringify({sid, op: "test", status: "http_busy"}));
await settle();
takeCommand("mute", true);
assert.match(element("test-result").textContent, /another script.*releases the connection/i);
assert.equal(element("audio-controls").disabled, false);

click("off");
await settle();
const [testTimeout] = timers.values();
assert.equal(testTimeout.delay, 18000);
testTimeout.handler();
await settle();
takeCommand("off");
assert.match(element("test-result").textContent, /No result.*Check your TV/);
assert.equal(commands.length, 0);
assert.equal(element("off").disabled, false);
console.log("PASS pending tests require a deadline, correlate replies, and report busy or unknown outcomes");
