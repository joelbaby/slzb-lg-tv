# SPDX-License-Identifier: MIT
# Exercise the installed script's BeApp and ISC interfaces with firmware substitutes.
import introspect
import json

var events = []
var replies = []
var requests = []
var results = []
var files = {}
var fault_path = "/beapps/lg_tv/.settings-1.json"
var failed_settings_write = false
var failed_settings_readback = false
var fail_read = {}
var deny_delete = {}
var clock = 1000
var wake_destination = nil
var wakes = 0
var test_done = false

var beapp = module("BEAPP")
beapp.claim = def () return 130 end
beapp.receive = def (channel, timeout)
    assert(channel == 130 && timeout <= 100)
    if size(events) > 0
        return events.pop(0)
    end
    clock += timeout
    if size(requests) == 0
        test_done = true
        raise "test_finished"
    end
end
beapp.send = def (channel, raw)
    assert(channel == 130)
    replies.push(json.load(raw))
    return 1
end
beapp.log = def (line) end
introspect.setmodule("BEAPP", beapp)

var fs = module("FS")
class MemFile
    var path, mode
    def init(path, mode)
        self.path = path
        self.mode = mode
        if mode == "w" files[path] = "" end
    end
    def read(length)
        if fail_read.contains(self.path)
            fail_read.remove(self.path)
            raise "fixture_readback_failure"
        end
        return files[self.path]
    end
    def write(value)
        if self.path == fault_path
            if failed_settings_write
                files[self.path] = "{"
                raise "fixture_write_failure"
            end
            if failed_settings_readback fail_read[self.path] = true end
        end
        files[self.path] = value
    end
    def close() end
end
fs.open = def (path, mode) return MemFile(path, mode) end
fs.exists = def (path) return files.contains(path) end
fs.deleteFile = def (path)
    if deny_delete.contains(path) return false end
    return files.remove(path)
end
introspect.setmodule("FS", fs)

var isc = module("ISC")
isc.CH_TYPE_PRIVATE = 1
isc.CH_TYPE_PUBLIC = 2
isc.CH_TYPE_BROADCAST = 3
isc.claim = def (channel, kind) return true end
isc.release = def (channel) return true end
isc.receive = def (channel, timeout)
    assert(timeout == 0)
    if size(requests) > 0 return requests.pop(0) end
end
isc.send = def (channel, raw)
    results.push(json.load(raw))
    return 1
end
introspect.setmodule("ISC", isc)

var slzb = module("SLZB")
slzb.millis = def () return clock end
slzb.delay = def (ms) clock += ms end
introspect.setmodule("SLZB", slzb)
var wol = module("WOL")
wol.wake = def (mac)
    wake_destination = mac
    wakes += 1
    return true
end
introspect.setmodule("WOL", wol)
var http = module("HTTP")
var http_open = false
var http_calls = []
var http_status = 101
var lock_busy = false
var owns_lock = false
var fail_write = false
var delay_upgrade = 0
isc.claim = def (channel, kind)
    if kind == isc.CH_TYPE_PRIVATE
        if lock_busy || owns_lock return false end
        assert(channel == 62)
        owns_lock = true
    end
    return true
end
isc.release = def (channel)
    if channel == 62
        assert(owns_lock)
        owns_lock = false
    end
    return true
end
http.isOpened = def () return http_open end
http.open = def (url, verb, length, stream)
    assert(!http_open && url == "https://10.0.0.25:3001/")
    assert(verb == "get" && length == 0 && stream)
    http_open = true
    http_calls.push("open")
    return true
end
http.setHeader = def (header, value)
    if header == "Sec-WebSocket-Key" assert(size(value) == 24) end
    return true
end
http.completeStreamConfig = def () end
http.perform = def ()
    clock += delay_upgrade
    return http_status
end
http.close = def ()
    assert(owns_lock && http_open)
    http_open = false
    http_calls.push("close")
end
http.streamWriteBytes = def (frame)
    if fail_write raise "fixture_write_failure" end
    assert(http_open && frame.get(0) == 0x81 && (frame.get(1) & 128) != 0)
    var length = frame.get(1) & 127
    var offset = 2
    if length == 126
        length = (frame.get(2) << 8) | frame.get(3)
        offset = 4
    end
    assert(length + offset + 4 == frame.size())
    var decoded = bytes()
    for index : 0 .. length - 1
        decoded.add(frame.get(offset + 4 + index) ^ frame.get(offset + index % 4))
    end
    http_calls.push(json.load(decoded.asstring()))
end
introspect.setmodule("HTTP", http)
var network = module("NETWORK")
network.isReady = def () return true end
introspect.setmodule("NETWORK", network)

var tcp_opens = 0
var tcp_closes = 0
class TCP_CLIENT
    def connect(host, port, timeout)
        assert(host == "10.0.0.25" && port == 3001 && timeout <= 2500)
        tcp_opens += 1
        return true
    end
    def close() tcp_closes += 1 end
    def write(data) return data.size() end
    def waitAvailable(timeout) return 0 end
    def connected() return true end
end

var session_id = "f00102030405060708090a0b0c0d0e00"

def ui(fields)
    if !fields.contains("sid") fields["sid"] = session_id end
    events.push(json.dump({"event":"msg", "data":json.dump(fields)}))
end

def configure()
    ui({"cmd":"configure", "host":"10.0.0.25", "mac":"02:00:00:00:00:25",
        "request":60, "result":61, "lock":62})
end

def request(action, id, expires, value)
    var message = {"v":1, "action":action, "id":id, "expires":expires}
    if value != nil message["value"] = value end
    requests.push(json.dump(message))
end

def run()
    test_done = false
    try
        compile("app/app.be", "file")()
    except .. as error, message
        if !test_done || error != "test_finished" raise error, message end
    end
end

configure()
run()
assert(replies[0]["status"] == "saved")

# Independent request after restarting the app, with no BeApp events.
request("on", "test-wake", 10000)
run()
assert(size(results) == 1)
assert(results[0]["id"] == "test-wake")
assert(results[0]["status"] == "submitted")
assert(wakes == 1 && wake_destination == "02:00:00:00:00:25")
print("PASS persisted configuration supports browser-free Wake-on-LAN")


request("off", "requires-pairing", clock + 10000)
run()
assert(results[-1]["status"] == "not_paired")
assert(size(http_calls) == 0)

# Model a prior successful pairing across a backend restart.
var key = "synthetic-client-key"
var pin = "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899"
ui({"cmd":"open"})
ui({"cmd":"step", "seq":0, "tx":"0342"})
ui({"cmd":"reopen"})
ui({"cmd":"step", "seq":0, "tx":"0599"})
ui({"cmd":"save", "key":key, "pin":pin})
ui({"cmd":"status"})
run()
assert(replies[-2]["status"] == "paired" && replies[-1]["paired"])
assert(tcp_opens == 2 && tcp_closes == 2)
assert(!replies[-1].contains("key") && !replies[-2].contains("key"))
print("PASS Pair persists registration without returning credentials")

request("off", "test-off", clock + 10000)
run()
assert(results[-1]["status"] == "submitted")
assert(http_calls[0] == "open" && http_calls[3] == "close")
assert(http_calls[1]["type"] == "register")
assert(http_calls[1]["payload"]["client-key"] == "synthetic-client-key")
assert(http_calls[1]["payload"]["manifest"]["permissions"][0] == "CONTROL_POWER")
assert(http_calls[2]["uri"] == "ssap://system/turnOff")

http_calls = []
http_open = true
request("off", "opened-client", clock + 10000)
run()
assert(results[-1]["status"] == "http_busy")
assert(size(http_calls) == 0 && http_open)

http_open = false
lock_busy = true
request("off", "locked-client", clock + 10000)
run()
assert(results[-1]["status"] == "http_busy")
assert(size(http_calls) == 0 && !http_open)
lock_busy = false

http_status = 403
request("off", "upgrade-rejected", clock + 10000)
run()
assert(results[-1]["status"] == "upgrade_failed")
assert(size(http_calls) == 2 && http_calls[-1] == "close")
assert(!http_open && !owns_lock)

http_status = 101
http_calls = []
fail_write = true
request("off", "broken-stream", clock + 10000)
run()
assert(results[-1]["status"] == "transport_failed")
assert(size(http_calls) == 2 && http_calls[0] == "open" && http_calls[-1] == "close")
assert(!http_open && !owns_lock)
fail_write = false

http_calls = []
delay_upgrade = 1000
request("off", "expired-after-registration", clock + 1600)
run()
assert(results[-1]["status"] == "expired")
assert(size(http_calls) == 3 && http_calls[1]["type"] == "register")
assert(http_calls[-1] == "close" && !owns_lock)
delay_upgrade = 0
print("PASS native Off sends masked frames, respects busy HTTP and expiry, and closes its own client")

ui({"cmd":"configure", "host":"203.0.113.25", "mac":"02:00:00:00:00:25",
    "request":60, "result":61, "lock":62})
ui({"cmd":"configure", "host":"10.0.0.26", "mac":"02:00:00:00:00:26",
    "request":60, "result":61, "lock":62})
ui({"cmd":"status"})
run()
assert(replies[-3]["status"] == "invalid_config")
assert(replies[-2]["status"] == "forget_first")
assert(replies[-1]["config"]["host"] == "10.0.0.25" && replies[-1]["paired"])
print("PASS rejected settings changes preserve the existing TV and pairing")

def change_mac(mac)
    ui({"cmd":"configure", "host":"10.0.0.25", "mac":mac,
        "request":60, "result":61, "lock":62})
end

failed_settings_write = true
change_mac("02:00:00:00:00:27")
run()
assert(replies[-1]["status"] == "storage_failed")
failed_settings_write = false
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:25" && replies[-1]["paired"])

failed_settings_readback = true
change_mac("02:00:00:00:00:27")
run()
assert(replies[-1]["status"] == "storage_failed")
failed_settings_readback = false
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:25" && replies[-1]["paired"])

change_mac("02:00:00:00:00:27")
run()
assert(replies[-1]["status"] == "saved")
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:27" && replies[-1]["paired"])
# A later write reuses the old slot. An unreadable commit marker must roll back
# without selecting the new settings after restart.
fault_path = "/beapps/lg_tv/.settings-0.commit"
failed_settings_readback = true
change_mac("02:00:00:00:00:28")
run()
assert(replies[-1]["status"] == "storage_failed")
failed_settings_readback = false
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:27" && replies[-1]["paired"])
print("PASS failed settings writes and readback preserve the TV settings and pairing across restart")



ui({"cmd":"forget"})
ui({"cmd":"open"})
ui({"cmd":"forget"})
ui({"cmd":"save", "key":key, "pin":pin})  # Late message from the cancelled session.
ui({"cmd":"status"})
run()
assert(replies[-1]["paired"] == false)
assert(!files.contains("/beapps/lg_tv/.pairing.json"))
assert(tcp_opens == 3 && tcp_closes == 3)
request("off", "forgotten", clock + 10000)
run()
assert(results[-1]["status"] == "not_paired")
print("PASS Forget cancels pairing, deletes its credential, and rejects late saves")

var previous_wakes = wakes
request("on", "expired", clock - 1)
request("on", "duplicate", clock + 10000)
request("on", "duplicate", clock + 10000)
run()
assert(results[-3]["status"] == "expired")
assert(results[-2]["status"] == "submitted")
assert(results[-1]["status"] == "duplicate")
assert(wakes == previous_wakes + 1)
print("PASS stale and duplicate ISC requests do not repeat power commands")


# An installation's initial settings in the older format remain readable.
files = {"/beapps/lg_tv/.settings.json":json.dump({
    "host":"10.0.0.25", "mac":"02:00:00:00:00:25", "request":60, "result":61, "lock":62
})}
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:25")
change_mac("02:00:00:00:00:27")
run()
assert(replies[-1]["status"] == "saved")
ui({"cmd":"status"})
run()
assert(replies[-1]["config"]["mac"] == "02:00:00:00:00:27")
print("PASS legacy settings load and migrate on the next save")

# A power-only registration remains usable for Off without wider permissions.
files["/beapps/lg_tv/.pairing.json"] = json.dump({
    "host":"10.0.0.25", "key":"legacy-fixture-key", "pin":pin
})
request("volume", "legacy-volume", clock + 10000, 15)
request("off", "legacy-off", clock + 10000)
http_calls = []
run()
assert(results[-2]["status"] == "permissions_required")
assert(results[-1]["status"] == "submitted")
assert(size(http_calls) == 4)
assert(http_calls[1]["payload"]["client-key"] == "legacy-fixture-key")
assert(size(http_calls[1]["payload"]["manifest"]["permissions"]) == 1)
assert(http_calls[1]["payload"]["manifest"]["permissions"][0] == "CONTROL_POWER")
print("PASS power-only pairing retains Off and rejects new commands before touching HTTP")

def complete_pair(command, client_key)
    ui({"cmd":command})
    ui({"cmd":"step", "seq":0, "tx":"0342"})
    ui({"cmd":"reopen"})
    ui({"cmd":"step", "seq":0, "tx":"0599"})
    ui({"cmd":"save", "key":client_key, "pin":pin})
end

ui({"cmd":"upgrade"})
ui({"cmd":"step", "seq":0, "tx":"0342"})
ui({"cmd":"close"})
ui({"cmd":"save", "key":key, "pin":pin})
run()
request("volume", "cancelled-upgrade", clock + 10000, 15)
run()
assert(results[-1]["status"] == "permissions_required")

fault_path = "/beapps/lg_tv/.pairing-v2.commit"
failed_settings_readback = true
complete_pair("upgrade", key)
run()
assert(replies[-1]["status"] == "storage_failed")
failed_settings_readback = false
request("off", "failed-upgrade-off", clock + 10000)
http_calls = []
run()
assert(results[-1]["status"] == "submitted")
assert(http_calls[1]["payload"]["client-key"] == "legacy-fixture-key")
assert(size(http_calls[1]["payload"]["manifest"]["permissions"]) == 1)
print("PASS cancelled and interrupted permissions upgrades preserve the old key after restart")

failed_settings_readback = true
deny_delete["/beapps/lg_tv/.pairing-v2.commit"] = true
complete_pair("upgrade", key)
run()
assert(replies[-1]["status"] == "storage_failed")
failed_settings_readback = false
deny_delete = {}
request("off", "rollback-fallback-off", clock + 10000)
http_calls = []
run()
assert(results[-1]["status"] == "submitted")
assert(http_calls[1]["payload"]["client-key"] == "legacy-fixture-key")
print("PASS deleting the candidate preserves power-only pairing when the marker cannot be removed")

complete_pair("upgrade", key)
ui({"cmd":"status"})
run()
assert(replies[-2]["status"] == "paired" && replies[-1]["expanded"] == true)

def expect_tv_command(action, value, endpoint, payload_key, payload_value)
    http_calls = []
    request(action, "new-" + action, clock + 10000, value)
    run()
    assert(results[-1]["status"] == "submitted")
    assert(size(http_calls) == 4 && http_calls[0] == "open" && http_calls[-1] == "close")
    var registration = http_calls[1]["payload"]
    assert(registration["client-key"] == "synthetic-client-key")
    assert(json.dump(registration["manifest"]["permissions"]) ==
        '["CONTROL_POWER","CONTROL_AUDIO","CONTROL_INPUT_TV","LAUNCH","WRITE_NOTIFICATION_TOAST"]')
    assert(http_calls[2]["type"] == "request" && http_calls[2]["uri"] == "ssap://" + endpoint)
    if payload_key != nil
        var payload = http_calls[2]["payload"]
        assert(size(payload) == 1 && payload[payload_key] == payload_value)
    else
        assert(!http_calls[2].contains("payload"))
    end
end

expect_tv_command("volume", 15, "audio/setVolume", "volume", 15)
expect_tv_command("volume_up", nil, "audio/volumeUp")
expect_tv_command("volume_down", nil, "audio/volumeDown")
expect_tv_command("mute", true, "audio/setMute", "mute", true)
expect_tv_command("mute", false, "audio/setMute", "mute", false)
expect_tv_command("input", "HDMI_1", "tv/switchInput", "inputId", "HDMI_1")
expect_tv_command("launch", "youtube.leanback.v4", "system.launcher/launch", "id", "youtube.leanback.v4")
var toast = 'A "quoted" message with \\ and café'
expect_tv_command("notify", toast, "system.notifications/createToast", "message", toast)
print("PASS browser-free commands submit exact TV frames after an expanded pairing restart")

# The browser test uses the same validated command path and returns its own reply.
http_calls = []
var test_sid = "abcdef0123456789abcdef0123456789"
ui({"cmd":"prepare_test", "sid":test_sid})
run()
assert(replies[-1]["op"] == "prepare_test" && replies[-1]["sid"] == test_sid)
var deadline = replies[-1]["expires"]
assert(type(deadline) == "int" && deadline > clock)
ui({"cmd":"test", "action":"mute", "value":false, "sid":test_sid, "expires":deadline})
run()
assert(replies[-1]["op"] == "test" && replies[-1]["sid"] == test_sid)
assert(replies[-1]["status"] == "submitted")
assert(size(http_calls) == 4 && http_calls[2]["uri"] == "ssap://audio/setMute")
assert(http_calls[2]["payload"]["mute"] == false && !http_open && !owns_lock)
print("PASS browser test submits a validated mute command and correlates its reply")

http_calls = []
ui({"cmd":"test", "action":"volume", "value":120, "expires":clock + 10000})
run()
assert(replies[-1]["status"] == "invalid_request" && size(http_calls) == 0)
http_open = true
ui({"cmd":"test", "action":"input", "value":"HDMI_2", "expires":clock + 10000})
run()
assert(replies[-1]["status"] == "http_busy" && http_open && size(http_calls) == 0)
http_open = false
ui({"cmd":"test", "action":"mute", "value":true, "sid":test_sid, "expires":clock + 10000})
ui({"cmd":"test", "action":"mute", "value":true, "sid":test_sid, "expires":clock + 10000})
run()
assert(replies[-2]["status"] == "submitted" && replies[-1]["status"] == "duplicate")
assert(size(http_calls) == 4 && !http_open && !owns_lock)
print("PASS browser tests reject invalid values, busy clients, and repeated IDs")

http_calls = []
ui({"cmd":"prepare_test", "sid":test_sid})
run()
ui({"cmd":"test", "action":"off", "sid":test_sid, "expires":replies[-1]["expires"]})
clock += 18000 # The event sat in the queue until after the page timed out.
run()
assert(replies[-1]["status"] == "expired" && size(http_calls) == 0)
ui({"cmd":"test", "action":"off", "sid":test_sid})
run()
assert(replies[-1]["status"] == "invalid_request" && size(http_calls) == 0)
print("PASS browser tests need a deadline and never execute after it passes in the event queue")

http_calls = []
request("volume", "over-volume", clock + 10000, 101)
request("volume", "string-volume", clock + 10000, "15")
request("mute", "string-mute", clock + 10000, "false")
request("input", "bad-input", clock + 10000, "HDMI 1")
request("launch", "bad-app", clock + 10000, "https://example.invalid/")
request("notify", "bad-toast", clock + 10000, "\x01")
request("volume_up", "bad-step", clock + 10000, 2)
request("ssap://system/turnOff", "arbitrary-request", clock + 10000)
run()
for index : size(results) - 8 .. size(results) - 1
    assert(results[index]["status"] == "invalid_request")
end
assert(size(http_calls) == 0 && !http_open && !owns_lock)
print("PASS invalid commands never open HTTP or expose arbitrary TV endpoints")

var malformed = ["C0AF", "E282", "E228A1", "EDA080", "F4908080", "80"]
for index : 0 .. size(malformed) - 1
    var raw_text = bytes(malformed[index]).asstring()
    requests.push('{"v":1,"action":"notify","id":"bad-utf8-' + str(index) +
        '","expires":' + str(clock + 10000) + ',"value":"' + raw_text + '"}')
end
var before_invalid_text = size(results)
run()
assert(size(results) == before_invalid_text + size(malformed))
for index : before_invalid_text .. size(results) - 1
    assert(results[index]["status"] == "invalid_request")
end
assert(size(http_calls) == 0 && !http_open && !owns_lock)
print("PASS malformed UTF-8 notification values do not reach the TV")

ui({"cmd":"forget"})
run()
request("off", "forgot-upgraded-pairing", clock + 10000)
run()
assert(results[-1]["status"] == "not_paired")
assert(!files.contains("/beapps/lg_tv/.pairing.json") && !files.contains("/beapps/lg_tv/.pairing-v2.json"))
print("PASS Forget removes both versions of a pairing")

files["/beapps/lg_tv/.pairing.json"] = json.dump({
    "host":"10.0.0.25", "key":"legacy-fixture-key", "pin":pin
})
failed_settings_readback = true
deny_delete = {"/beapps/lg_tv/.pairing-v2.commit":true, "/beapps/lg_tv/.pairing-v2.json":true}
complete_pair("upgrade", key)
ui({"cmd":"status"})
run()
assert(replies[-2]["status"] == "storage_uncertain" && replies[-1]["expanded"] == true)
failed_settings_readback = false
deny_delete = {}
ui({"cmd":"status"})
run()
assert(replies[-1]["expanded"] == true)
expect_tv_command("volume", 15, "audio/setVolume", "volume", 15)
print("PASS an unverified rollback reports uncertainty and reloads the durable pairing")
