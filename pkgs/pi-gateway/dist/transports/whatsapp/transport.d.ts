import type { WhatsAppTransportConfig } from "../../config.js";
import type { InboundMessage } from "../../core/types.js";
type WhatsAppInbound = Omit<InboundMessage, "access">;
export declare class WhatsAppWebTransport {
    private readonly config;
    private client;
    private messageChain;
    constructor(config: WhatsAppTransportConfig);
    healthCheck(): Promise<void>;
    sendText(recipient: string, text: string): Promise<void>;
    startReceiving(onMessage: (msg: WhatsAppInbound) => Promise<void>): Promise<never>;
    private requireClient;
    private toChatJid;
}
export {};
//# sourceMappingURL=transport.d.ts.map