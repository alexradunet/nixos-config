import type { Message } from "whatsapp-web.js";
import type { InboundMessage } from "../../core/types.js";
export declare function parseWhatsAppMessage(input: Message): Promise<Omit<InboundMessage, "access"> | null>;
//# sourceMappingURL=parser.d.ts.map