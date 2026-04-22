import { access, mkdir } from "node:fs/promises";
import WhatsAppWeb from "whatsapp-web.js";
const { Client, LocalAuth } = WhatsAppWeb;
import { parseWhatsAppMessage } from "./parser.js";
export class WhatsAppWebTransport {
    config;
    client = null;
    messageChain = Promise.resolve();
    constructor(config) {
        this.config = config;
    }
    async healthCheck() {
        await mkdir(this.config.sessionDataPath, { recursive: true });
        if (this.config.chromiumExecutablePath) {
            await access(this.config.chromiumExecutablePath);
        }
    }
    async sendText(recipient, text) {
        const client = this.requireClient();
        const chatId = this.toChatJid(recipient);
        await client.sendMessage(chatId, text);
    }
    async startReceiving(onMessage) {
        await mkdir(this.config.sessionDataPath, { recursive: true });
        const client = new Client({
            authStrategy: new LocalAuth({ dataPath: this.config.sessionDataPath }),
            puppeteer: {
                headless: this.config.headless ?? true,
                executablePath: this.config.chromiumExecutablePath,
                args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
            },
        });
        this.client = client;
        client.on("qr", async (qr) => {
            console.log("WhatsApp QR received. Pair the dedicated Pi account to continue.");
            try {
                const QRCode = (await import("qrcode")).default;
                const fs = await import("node:fs");
                const path = await import("node:path");
                const qrDir = path.join(this.config.sessionDataPath, "..");
                const qrPath = path.join(qrDir, "whatsapp-qr.png");
                await QRCode.toFile(qrPath, qr, { width: 512 });
                console.log(`WhatsApp QR saved as image: ${qrPath}`);
            }
            catch (err) {
                console.error("Failed to save QR image:", err);
            }
        });
        client.on("authenticated", () => {
            console.log("WhatsApp authenticated.");
        });
        client.on("ready", () => {
            console.log("WhatsApp client ready.");
        });
        client.on("message", (message) => {
            this.messageChain = this.messageChain
                .catch(() => undefined)
                .then(async () => {
                const parsed = await parseWhatsAppMessage(message);
                if (parsed)
                    await onMessage(parsed);
            })
                .catch((err) => {
                console.error("Failed to handle WhatsApp message:", err);
            });
        });
        const readyPromise = new Promise((resolve, reject) => {
            let settled = false;
            const resolveOnce = () => {
                if (settled)
                    return;
                settled = true;
                resolve();
            };
            const rejectOnce = (err) => {
                if (settled)
                    return;
                settled = true;
                reject(err);
            };
            client.once("ready", resolveOnce);
            client.once("auth_failure", (message) => rejectOnce(new Error(`WhatsApp auth failure: ${message}`)));
            client.once("disconnected", (reason) => rejectOnce(new Error(`WhatsApp disconnected before ready: ${String(reason)}`)));
        });
        await client.initialize();
        await readyPromise;
        return new Promise((_resolve, reject) => {
            client.on("auth_failure", (message) => reject(new Error(`WhatsApp auth failure: ${message}`)));
            client.on("disconnected", (reason) => reject(new Error(`WhatsApp disconnected: ${String(reason)}`)));
        });
    }
    requireClient() {
        if (!this.client)
            throw new Error("WhatsApp client is not initialized yet");
        return this.client;
    }
    toChatJid(recipient) {
        const raw = recipient.startsWith("whatsapp:") ? recipient.slice("whatsapp:".length) : recipient;
        if (raw.startsWith("+"))
            return `${raw.slice(1)}@c.us`;
        if (raw.includes("@"))
            return raw;
        if (/^\d+$/.test(raw))
            return `${raw}@c.us`;
        throw new Error(`Unsupported WhatsApp recipient id: ${recipient}`);
    }
}
//# sourceMappingURL=transport.js.map