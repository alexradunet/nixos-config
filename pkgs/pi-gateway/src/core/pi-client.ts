import { execFile } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type PromptOptions = {
  systemPromptAddendum?: string;
};

/** Wraps the pi CLI in print mode for non-interactive gateway use. */
export class PiClient {
  constructor(
    private readonly piBin: string,
    private readonly sessionDir: string,
    private readonly cwd: string,
    private readonly timeoutMs: number = 5 * 60 * 1000,
  ) {
    mkdirSync(this.sessionDir, { recursive: true });
  }

  async prompt(
    message: string,
    sessionPath: string | null,
    options: PromptOptions = {},
  ): Promise<{ text: string; sessionPath: string }> {
    const resolved = sessionPath ?? join(this.sessionDir, `session-${Date.now()}-${Math.random().toString(36).slice(2)}.jsonl`);

    const args = [
      "--print",
      "--session", resolved,
      "--system-prompt", this.buildSystemPrompt(options.systemPromptAddendum),
      message,
    ];

    const { stdout, stderr } = await execFileAsync(this.piBin, args, {
      cwd: this.cwd,
      timeout: this.timeoutMs,
      maxBuffer: 10 * 1024 * 1024,
      env: process.env,
    }).catch((err: any) => {
      const out = err.stdout ?? "";
      const text = out.trim() || err.stderr?.trim() || "Pi returned an error.";
      throw new Error(`pi exited with code ${err.code ?? "?"}: ${text}`);
    });

    const text = stdout.trim() || stderr.trim() || "Pi returned an empty reply.";
    return { text, sessionPath: resolved };
  }

  async healthCheck(): Promise<void> {
    try {
      const { stdout } = await execFileAsync(this.piBin, ["--version"], {
        timeout: 10_000,
        env: process.env,
      });
      if (!stdout.trim()) {
        console.warn("pi --version returned empty stdout, but binary exists. Continuing.");
      }
    } catch (err) {
      console.warn("pi health check failed, but continuing:", err);
    }
  }

  private buildSystemPrompt(addendum?: string): string {
    return [
      "You are replying through a messaging gateway.",
      "Keep replies concise, plain-text, and mobile-friendly.",
      "Avoid markdown-heavy formatting, large code blocks, and tables unless explicitly requested.",
      "Do not perform privileged or destructive system actions from this channel.",
      addendum?.trim() ?? "",
    ]
      .filter(Boolean)
      .join(" ");
  }
}
