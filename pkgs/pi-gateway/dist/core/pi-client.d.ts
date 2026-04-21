/** Wraps the pi CLI in print mode for non-interactive gateway use. */
export declare class PiClient {
    private readonly piBin;
    private readonly sessionDir;
    private readonly cwd;
    private readonly timeoutMs;
    constructor(piBin: string, sessionDir: string, cwd: string, timeoutMs?: number);
    prompt(message: string, sessionPath: string | null): Promise<{
        text: string;
        sessionPath: string;
    }>;
    healthCheck(): Promise<void>;
    private buildSystemPrompt;
}
//# sourceMappingURL=pi-client.d.ts.map