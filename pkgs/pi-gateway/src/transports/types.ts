import type { InboundMessage } from "../core/types.js";

/** Every transport module implements this interface. */
export interface GatewayTransport {
  readonly name: string;
  healthCheck(): Promise<void>;
  startReceiving(onMessage: (msg: InboundMessage) => Promise<void>): Promise<never>;
  sendText(message: InboundMessage, text: string): Promise<void>;
  sendTextToRecipient(recipientId: string, text: string): Promise<void>;
}
