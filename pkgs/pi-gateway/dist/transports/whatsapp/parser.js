import { createHash } from "node:crypto";
function toIsoFromUnixSeconds(ts) {
    return new Date(ts * 1000).toISOString();
}
function hashMessage(parts) {
    return createHash("sha256").update(parts.join("|")).digest("hex");
}
function normalizePhoneLike(value) {
    const digits = value.replace(/\D/g, "");
    if (!digits)
        return value;
    return `+${digits}`;
}
function normalizeSenderId(jid) {
    const bare = jid.split("@")[0] ?? jid;
    if (/^\d+$/.test(bare))
        return `whatsapp:${normalizePhoneLike(bare)}`;
    return `whatsapp:${bare}`;
}
function normalizeChatId(jid) {
    const bare = jid.split("@")[0] ?? jid;
    if (jid.endsWith("@g.us"))
        return `whatsapp-group:${bare}`;
    if (/^\d+$/.test(bare))
        return `whatsapp:${normalizePhoneLike(bare)}`;
    return `whatsapp:${bare}`;
}
async function resolveSenderName(message) {
    try {
        const contact = await message.getContact();
        return contact.pushname ?? contact.name ?? contact.shortName ?? contact.number ?? undefined;
    }
    catch {
        return undefined;
    }
}
export async function parseWhatsAppMessage(input) {
    if (input.fromMe)
        return null;
    if (input.isStatus)
        return null;
    const text = input.body?.trim() ?? "";
    if (!text)
        return null;
    const isGroup = input.from.endsWith("@g.us");
    const senderJid = isGroup ? input.author : input.from;
    if (!senderJid)
        return null;
    const chatId = normalizeChatId(input.from);
    const senderId = normalizeSenderId(senderJid);
    const serializedId = input.id?._serialized?.trim();
    const messageId = serializedId
        ? `whatsapp:${serializedId}`
        : `whatsapp:${hashMessage([senderJid, input.from, String(input.timestamp), text])}`;
    return {
        channel: "whatsapp",
        chatId,
        senderId,
        senderName: await resolveSenderName(input),
        messageId,
        timestamp: toIsoFromUnixSeconds(input.timestamp),
        text,
        isGroup,
    };
}
//# sourceMappingURL=parser.js.map