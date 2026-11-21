# SPDX-License-Identifier: MIT
# Run once in the main flow of a Berry script. Choose an action and value.
# "on", "off", "volume_up", "volume_down" use nil.
# "volume" uses a number from 0 to 100, e.g. 15.
# "mute" uses true to mute or false to unmute.
# "input" uses an input ID, e.g. "HDMI_1".
# "launch" uses an installed app ID, e.g. "youtube.leanback.v4".
# "notify" uses a short message, e.g. "The washer has finished".
import ISC
import SLZB
import json
import math

var action = "off"
var value = nil
var command_channel = 60
var result_channel = 61
var millis_mask = 0x7fffffff

def send_tv_command(action, value)
    if !ISC.claim(command_channel, ISC.CH_TYPE_PUBLIC) return "channel_busy" end
    if !ISC.subscribe(result_channel)
        ISC.release(command_channel)
        return "channel_busy"
    end

    var started = SLZB.millis() & millis_mask
    var id = "manual-" + str(started) + "-" + str(math.rand())
    var expires = (started + 15000) & millis_mask
    var status = "unknown"
    var request = {"v":1, "action":action, "id":id, "expires":expires}
    if value != nil request["value"] = value end
    if ISC.send(command_channel, json.dump(request))
        while (((SLZB.millis() & millis_mask) - started) & millis_mask) < 17000
            var raw = ISC.receive(result_channel, 250)
            if raw == nil continue end
            var reply = json.load(raw)
            if isinstance(reply, map) && reply.find("v") == 1 && reply.find("id") == id
                status = reply.find("status", "unknown")
                break
            end
        end
    else
        status = "queue_busy"
    end
    ISC.unsubscribe(result_channel)
    ISC.release(command_channel)
    return status
end

SLZB.log("LG TV " + action + ": " + send_tv_command(action, value))
