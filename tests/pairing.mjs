/* SPDX-License-Identifier: MIT */
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { X509Certificate, webcrypto } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createConnection } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout } from "node:timers/promises";
import createTls from "../dist/tls.js";
import protocol from "../app/protocol.js";
import { startFixture } from "./fixture.mjs";

globalThis.crypto ??= webcrypto;
const dir = mkdtempSync(join(tmpdir(), "lg-tv-test-"));
let cert;
let key;
try {
    execFileSync("openssl", [
        "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes", "-days", "1",
        "-subj", "/CN=pairing-test", "-keyout", join(dir, "key.pem"), "-out", join(dir, "cert.pem")
    ], {stdio: "ignore"});
    cert = readFileSync(join(dir, "cert.pem"));
    key = readFileSync(join(dir, "key.pem"));
} finally {
    rmSync(dir, {recursive: true, force: true});
}

const correctPin = new X509Certificate(cert).fingerprint256.replaceAll(":", "").toLowerCase();
const events = [];
const fixtureOptions = {cert, key, observe: event => events.push(event)};

async function run(port, pin, existingKey) {
    const pieces = [];
    const socket = createConnection({host: "127.0.0.1", port});
    let disconnected = false;
    socket.on("data", data => pieces.push(...data));
    socket.on("error", () => { disconnected = true; });
    socket.on("end", () => { disconnected = true; });
    const deadline = Date.now() + 6000;
    const exchange = async bytes => {
        if (Date.now() > deadline) throw new Error("Fixture deadline exceeded");
        if (bytes.length) socket.write(bytes);
        await setTimeout(8);
        if (!pieces.length && disconnected) throw new Error("Fixture disconnected");
        return Uint8Array.from(pieces.splice(0, 37));
    };
    try {
        const tls = new protocol.TlsStream(await createTls(), exchange, pin);
        const ws = new protocol.WebSocketStream(tls);
        await ws.connect("127.0.0.1");
        assert.equal(tls.pin, correctPin);
        let prompted = false;
        const registeredKey = await protocol.register(ws, () => { prompted = true; }, existingKey);
        assert.equal(registeredKey, "fixture-only-synthetic-key");
        assert.equal(prompted, !existingKey);
        return registeredKey;
    } finally {
        socket.destroy();
    }
}

async function withFixture(options, test) {
    const server = await startFixture({...fixtureOptions, ...options});
    try {
        await test(server.address().port);
    } finally {
        server.close();
    }
}

await withFixture({}, async port => {
    const registration = await run(port);
    await run(port, correctPin, registration);
    await assert.rejects(run(port, "00".repeat(32)), /fingerprint changed/);
});
await withFixture({badUpgrade: true}, async port => {
    await assert.rejects(run(port), /Invalid WebSocket upgrade/);
});
await withFixture({rejectPairing: true}, async port => {
    await assert.rejects(run(port), /TV rejected registration/);
});
assert(events.includes("Fragmented matching registered reply sent"));
assert(events.includes("Saved key re-registered"));
assert(events.includes("Masked pong received"));
assert(!events.includes("Fixture protocol validation failed"));
console.log("PASS pairing over a bodyless 101, fragmented registration, pin check, and invalid upgrade/denial");
