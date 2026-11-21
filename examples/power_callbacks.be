# SPDX-License-Identifier: MIT
# Add to your automation. In an event callback, call tv_request("off") for power
# or tv_request("volume", 15), tv_request("mute", true), tv_request("input", "HDMI_1"),
# tv_request("launch", "youtube.leanback.v4"), or tv_request("notify", "Doorbell").
# Results are delivered to tv_result() on a later timer tick.
import ISC
import SLZB
import TIMER
import json
import math

var command_channel = 60
var result_channel = 61
var millis_mask = 0x7fffffff
var subscribed = ISC.subscribe(result_channel)
var claimed = subscribed && ISC.claim(command_channel, ISC.CH_TYPE_PUBLIC)
if subscribed && !claimed ISC.unsubscribe(result_channel) end
var pending = nil

def tv_result(action, status)
    SLZB.log("LG TV " + action + ": " + status)
end

def tv_request(action, value)
    if !claimed || pending != nil return false end
    var started = SLZB.millis() & millis_mask
    var id = "event-" + str(started) + "-" + str(math.rand())
    var expires = (started + 15000) & millis_mask
    var request = {"v":1, "action":action, "id":id, "expires":expires}
    if value != nil request["value"] = value end
    if !ISC.send(command_channel, json.dump(request))
        tv_result(action, "queue_busy")
        return false
    end
    pending = {"id":id, "action":action, "started":started}
    return true
end

def check_tv_result()
    # Each subscriber has a bounded queue. Drain it without waiting.
    while ISC.available(result_channel) > 0
        var raw = ISC.receive(result_channel, 0)
        if raw == nil break end
        var reply = json.load(raw)
        if pending != nil && isinstance(reply, map) && reply.find("v") == 1 &&
            reply.find("id") == pending["id"]
            var action = pending["action"]
            pending = nil
            tv_result(action, reply.find("status", "unknown"))
        end
    end
    if pending != nil
        var elapsed = ((SLZB.millis() & millis_mask) - pending["started"]) & millis_mask
        if elapsed >= 17000
            var action = pending["action"]
            pending = nil
            tv_result(action, "unknown")
        end
    end
end

if claimed
    TIMER.setInterval(check_tv_result, 250)
else
    SLZB.log("LG TV script channels are in use")
end
