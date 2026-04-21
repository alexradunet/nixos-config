import { loadConfig } from "./config.js";
import { Store } from "./core/store.js";
import { PiClient } from "./core/pi-client.js";
import { Policy } from "./core/policy.js";
import { Router } from "./core/router.js";
import { SignalTransport } from "./transports/signal/index.js";
async function main() {
    const configPath = process.argv[2] ?? "./pi-gateway.yml";
    const config = loadConfig(configPath);
    const transports = [];
    if (config.transports.signal?.enabled) {
        transports.push(new SignalTransport(config.transports.signal));
    }
    if (transports.length === 0) {
        throw new Error("No transports enabled in pi-gateway config. Enable at least one under transports:");
    }
    const store = new Store(config.gateway.dbPath);
    const pi = new PiClient(config.pi.bin, config.gateway.sessionDir, config.pi.cwd, config.pi.timeoutMs);
    const policy = new Policy();
    const router = new Router(store, pi, policy, config.gateway.maxReplyChars, config.gateway.maxReplyChunks);
    await pi.healthCheck();
    console.log("pi health check OK");
    for (const transport of transports) {
        await transport.healthCheck();
        console.log(`${transport.name} transport health check OK`);
    }
    console.log(`Pi gateway started with transports: ${transports.map((t) => t.name).join(", ")}`);
    await Promise.all(transports.map((transport) => transport.startReceiving(async (msg) => {
        const result = await router.handleMessage(msg);
        for (const reply of result.replies) {
            await transport.sendText(msg, reply);
        }
        if (result.markProcessed) {
            store.markProcessed(msg.messageId, msg.chatId, msg.senderId, msg.timestamp);
        }
    })));
}
main().catch((err) => {
    console.error("pi-gateway fatal:", err);
    process.exit(1);
});
//# sourceMappingURL=main.js.map