/* SPDX-License-Identifier: MIT */
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import tls from "node:tls";

const syntheticKey = "fixture-only-synthetic-key";

function frame(opcode, payload, fin = true) {
    const bytes = Buffer.from(payload);
    assert(bytes.length <= 125);
    return Buffer.concat([Buffer.from([(fin ? 128 : 0) | opcode, bytes.length]), bytes]);
}

export function startFixture({cert, key, badUpgrade = false, rejectPairing = false, observe = () => {}}) {
    const server = tls.createServer({
        cert, key, minVersion: "TLSv1.2", maxVersion: "TLSv1.2",
        handshakeTimeout: 4000
    }, socket => {
        observe("TLS " + socket.getProtocol() + " " + socket.getCipher().name);
        socket.setTimeout(35000, () => socket.destroy());
        socket.setNoDelay(true);
        let pending = Buffer.alloc(0);
        let upgraded = false;
        socket.on("error", () => {});
        socket.on("data", data => {
            try {
                pending = Buffer.concat([pending, data]);
                if (pending.length > 4096) throw new Error("oversize fixture request");
                if (!upgraded) {
                    const end = pending.indexOf("\r\n\r\n");
                    if (end < 0) return;
                    const request = pending.subarray(0, end).toString("ascii");
                    assert.match(request, /^GET \/ HTTP\/1.1\r\n/);
                    assert.match(request, /\r\nSec-WebSocket-Version: 13\b/i);
                    const key = request.match(/\r\nSec-WebSocket-Key: (\S+)/i)[1];
                    const accept = createHash("sha1").update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
                    const response = "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n" +
                        "Sec-WebSocket-Accept: " + (badUpgrade ? "invalid" : accept) + "\r\n\r\n";
                    socket.write(response.slice(0, 30));
                    setTimeout(() => socket.write(response.slice(30)), 20);
                    pending = pending.subarray(end + 4);
                    upgraded = true;
                    observe("Bodyless 101, split across TLS writes");
                }
                while (pending.length >= 2) {
                    assert(pending[0] & 128);
                    assert(pending[1] & 128, "client frames must be masked");
                    const opcode = pending[0] & 15;
                    let length = pending[1] & 127;
                    let offset = 2;
                    if (length === 126) {
                        if (pending.length < 4) return;
                        length = pending.readUInt16BE(2);
                        offset = 4;
                    }
                    if (pending.length < offset + 4 + length) return;
                    const mask = pending.subarray(offset, offset + 4);
                    const payload = pending.subarray(offset + 4, offset + 4 + length)
                        .map((value, index) => value ^ mask[index % 4]);
                    pending = pending.subarray(offset + 4 + length);
                    if (opcode === 10) {
                        assert.equal(payload.toString(), "test-ping");
                        observe("Masked pong received");
                        continue;
                    }
                    assert.equal(opcode, 1);
                    const request = JSON.parse(payload);
                    assert.equal(request.type, "register");
                    assert.equal(request.payload.pairingType, "PROMPT");
                    assert.deepEqual(request.payload.manifest.permissions, [
                        "CONTROL_POWER", "CONTROL_AUDIO", "CONTROL_INPUT_TV",
                        "LAUNCH", "WRITE_NOTIFICATION_TOAST"
                    ]);
                    if (rejectPairing) {
                        socket.write(frame(1, JSON.stringify({type: "error", id: request.id})));
                        continue;
                    }
                    const key = request.payload["client-key"];
                    if (key) assert.equal(key, syntheticKey);
                    else {
                        socket.write(frame(1, JSON.stringify({
                            type: "registered", id: "unrelated", payload: { "client-key": "ignore-me" }
                        })));
                        socket.write(frame(1, JSON.stringify({
                            type: "response", id: request.id, payload: { pairingType: "PROMPT" }
                        })));
                    }
                    const reply = JSON.stringify({
                        type: "registered", id: request.id, payload: { "client-key": syntheticKey }
                    });
                    setTimeout(() => {
                        const initial = frame(1, reply.slice(0, 32), false);
                        socket.write(initial.subarray(0, 1));
                        setTimeout(() => {
                            socket.write(Buffer.concat([
                                initial.subarray(1), frame(9, "test-ping"), frame(0, reply.slice(32))
                            ]));
                            observe(key ? "Saved key re-registered" : "Fragmented matching registered reply sent");
                        }, 35);
                    }, key ? 25 : 250);
                }
            } catch (error) {
                observe("Fixture protocol validation failed");
                socket.destroy(error);
            }
        });
        socket.on("close", () => observe("Fixture TCP closed"));
    });
    return new Promise((resolve, reject) => {
        server.once("error", reject);
        server.listen(0, "127.0.0.1", () => resolve(server));
    });
}
