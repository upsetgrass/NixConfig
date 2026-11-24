import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getKeybindings } from "@earendil-works/pi-tui";

type Phase = "idle" | "working" | "done" | "error" | "exited";

const labels: Record<Phase | "waiting" | "suspended", string> = {
  idle: "待命",
  working: "运行中",
  waiting: "待反馈",
  done: "已完成",
  error: "出错",
  suspended: "已挂起",
  exited: "已退出",
};

// Only the status and session identity belong in a terminal title, never prompt text.
function safe(text: string): string {
  return text.replace(/[\x00-\x1f\x7f-\x9f]/g, " ").trim().slice(0, 48);
}

export default function tabStatus(pi: ExtensionAPI) {
  let phase: Phase = "idle";
  let waiting = false;
  let suspended = false;
  let failed = false;
  let removeInput: (() => void) | undefined;
  let resume: (() => void) | undefined;
  let renameTimer: ReturnType<typeof setTimeout> | undefined;

  function update(ctx: ExtensionContext) {
    if (ctx.mode !== "tui") return;
    const name = pi.getSessionName();
    const identity = name ? `${safe(name)} · ${safe(path.basename(ctx.cwd))}` : safe(path.basename(ctx.cwd));
    const state = suspended ? "suspended" : waiting ? "waiting" : phase;
    ctx.ui.setTitle(`[${labels[state]}] π · ${identity}`);
  }

  pi.on("session_start", (_event, ctx) => {
    phase = "idle";
    waiting = false;
    failed = false;
    suspended = false;
    if (ctx.mode === "tui" && process.platform !== "win32") {
      // Observe the configured suspend key; leave Pi's actual job control alone.
      removeInput = ctx.ui.onTerminalInput((data) => {
        if (!waiting && getKeybindings().matches(data, "app.suspend")) {
          suspended = true;
          update(ctx);
        }
        return undefined;
      });
      resume = () => {
        suspended = false;
        update(ctx);
      };
      process.on("SIGCONT", resume);
    }
    update(ctx);
  });
  pi.on("before_agent_start", (_event, ctx) => {
    failed = false;
    phase = "working";
    update(ctx);
  });
  pi.on("agent_start", (_event, ctx) => {
    phase = "working";
    update(ctx);
  });
  pi.on("ui_prompt_start", (_event, ctx) => {
    waiting = true;
    update(ctx);
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    waiting = false;
    update(ctx);
  });
  pi.on("message_end", (event) => {
    if (event.message.role === "assistant") {
      failed = event.message.stopReason === "error";
    }
  });
  pi.on("agent_settled", (event, ctx) => {
    phase = event.aborted ? "idle" : failed ? "error" : "done";
    update(ctx);
  });
  pi.on("session_info_changed", (_event, ctx) => {
    // Pi also writes its built-in title on this event; restore ours after it.
    if (renameTimer) clearTimeout(renameTimer);
    renameTimer = setTimeout(() => {
      renameTimer = undefined;
      update(ctx);
    }, 0);
  });
  pi.on("session_shutdown", (event, ctx) => {
    removeInput?.();
    removeInput = undefined;
    if (resume) process.off("SIGCONT", resume);
    resume = undefined;
    suspended = false;
    if (renameTimer) clearTimeout(renameTimer);
    renameTimer = undefined;
    if (event.reason === "quit") {
      phase = "exited";
      waiting = false;
      update(ctx);
    }
  });
}
