import { access, mkdir } from "node:fs/promises";
import WhatsAppWeb from "whatsapp-web.js";
import type { Message } from "whatsapp-web.js";

const { Client, LocalAuth } = WhatsAppWeb;
type WhatsAppClient = InstanceType<typeof Client>;
import type { WhatsAppTransportConfig } from "../../config.js";
import type { InboundMessage } from "../../core/types.js";
import { parseWhatsAppMessage } from "./parser.js";

type WhatsAppInbound = Omit<InboundMessage, "access">;

export class WhatsAppWebTransport {
  private client: WhatsAppClient | null = null;
  private messageChain: Promise<void> = Promise.resolve();

  constructor(private readonly config: WhatsAppTransportConfig) {}

  async healthCheck(): Promise<void> {
    await mkdir(this.config.sessionDataPath, { recursive: true });
    if (this.config.chromiumExecutablePath) {
      await access(this.config.chromiumExecutablePath);
    }
  }

  async sendText(recipient: string, text: string): Promise<void> {
    const client = this.requireClient();
    const chatId = this.toChatJid(recipient);
    await client.sendMessage(chatId, text);
  }

  async startReceiving(onMessage: (msg: WhatsAppInbound) => Promise<void>): Promise<never> {
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

    client.on("qr", () => {
      console.log("WhatsApp QR received. Pair the dedicated Pi account to continue.");
    });
    client.on("authenticated", () => {
      console.log("WhatsApp authenticated.");
    });
    client.on("ready", () => {
      console.log("WhatsApp client ready.");
    });
    client.on("message", (message: Message) => {
      this.messageChain = this.messageChain
        .catch(() => undefined)
        .then(async () => {
          const parsed = await parseWhatsAppMessage(message);
          if (parsed) await onMessage(parsed);
        })
        .catch((err) => {
          console.error("Failed to handle WhatsApp message:", err);
        });
    });

    const readyPromise = new Promise<void>((resolve, reject) => {
      let settled = false;
      const resolveOnce = () => {
        if (settled) return;
        settled = true;
        resolve();
      };
      const rejectOnce = (err: Error) => {
        if (settled) return;
        settled = true;
        reject(err);
      };

      client.once("ready", resolveOnce);
      client.once("auth_failure", (message) => rejectOnce(new Error(`WhatsApp auth failure: ${message}`)));
      client.once("disconnected", (reason) =>
        rejectOnce(new Error(`WhatsApp disconnected before ready: ${String(reason)}`)),
      );
    });

    await client.initialize();
    await readyPromise;

    return new Promise<never>((_resolve, reject) => {
      client.on("auth_failure", (message) => reject(new Error(`WhatsApp auth failure: ${message}`)));
      client.on("disconnected", (reason) => reject(new Error(`WhatsApp disconnected: ${String(reason)}`)));
    });
  }

  private requireClient(): WhatsAppClient {
    if (!this.client) throw new Error("WhatsApp client is not initialized yet");
    return this.client;
  }

  private toChatJid(recipient: string): string {
    const raw = recipient.startsWith("whatsapp:") ? recipient.slice("whatsapp:".length) : recipient;
    if (raw.startsWith("+")) return `${raw.slice(1)}@c.us`;
    if (raw.includes("@")) return raw;
    if (/^\d+$/.test(raw)) return `${raw}@c.us`;
    throw new Error(`Unsupported WhatsApp recipient id: ${recipient}`);
  }
}
