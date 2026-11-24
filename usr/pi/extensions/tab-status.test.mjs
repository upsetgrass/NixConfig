import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { stripTypeScriptTypes } from "node:module";

// Exercise real handlers with a fake UI and process; no model calls or OS signals.
const source = readFileSync(new URL("./tab-status.ts", import.meta.url), "utf8");
const js = stripTypeScriptTypes(source).replace(/^import .*;\n/gm, "").replace("export default function", "function");
const signals = new EventEmitter();
signals.platform = "linux";
const factory = runInNewContext(`${js}\ntabStatus`, {
  path: { basename: (value) => value.split("/").pop() },
  process: signals,
  setTimeout, clearTimeout,
  getKeybindings: () => ({ matches: (data, action) => data === "\x1a" && action === "app.suspend" }),
});
const handlers = new Map();
let name = "学习 Pi";
let title = "";
let input;
let listeners = 0;
const pi = {
  getSessionName: () => name,
  on: (type, handler) => handlers.set(type, handler),
};
const ctx = {
  mode: "tui", cwd: "/work/project",
  ui: {
    setTitle: (value) => { title = value; },
    onTerminalInput: (handler) => {
      listeners++;
      input = handler;
      return () => { listeners--; input = undefined; };
    },
  },
};
factory(pi);
const emit = (type, event = {}) => handlers.get(type)(event, ctx);
const has = (label) => assert.ok(title.startsWith(`[${label}]`), title);
emit("session_start"); has("待命");
emit("before_agent_start"); emit("agent_start"); has("运行中");
emit("ui_prompt_start"); has("待反馈");
emit("agent_start"); has("待反馈");
emit("ui_prompt_end"); has("运行中");
emit("agent_settled", { aborted: false }); has("已完成");
emit("ui_prompt_start"); emit("ui_prompt_end"); has("已完成");
emit("before_agent_start"); emit("message_end", { message: { role: "assistant", stopReason: "error" } });
emit("agent_settled", { aborted: false }); has("出错");
emit("before_agent_start"); emit("message_end", { message: { role: "assistant", stopReason: "error" } });
emit("agent_start"); emit("message_end", { message: { role: "assistant", stopReason: "stop" } });
emit("agent_settled", { aborted: false }); has("已完成");
emit("agent_settled", { aborted: true }); has("待命");
assert.equal(input("\x1a"), undefined); has("已挂起");
signals.emit("SIGCONT"); has("待命");
name = "new\x07name";
emit("session_info_changed");
await new Promise((resolve) => setTimeout(resolve, 5));
assert.ok(title.includes("new name"));
assert.ok(!title.includes("\x07"));
emit("session_info_changed"); emit("session_shutdown", { reason: "reload" });
assert.equal(listeners, 0); assert.equal(signals.listenerCount("SIGCONT"), 0);
emit("session_start"); assert.equal(listeners, 1);
emit("session_shutdown", { reason: "quit" }); has("已退出");
assert.equal(listeners, 0);
ctx.mode = "rpc"; title = "";
emit("session_start"); emit("agent_start"); emit("agent_settled", { aborted: false });
assert.equal(title, ""); assert.equal(listeners, 0);
console.log("Tab status: run/wait/settle, retry/error/abort, suspend/resume, rename/sanitize, reload cleanup and non-TUI checks passed.");
