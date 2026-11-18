import { createHash } from "node:crypto";
import { createReadStream, existsSync, mkdirSync, openSync, closeSync, writeSync, readFileSync,
  readdirSync, renameSync, statSync, chmodSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { DatabaseSync } from "node:sqlite";
import { pathToFileURL } from "node:url";

export const VERSION = 1;
const zeroUsage = () => ({
  input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
});
const text = value => typeof value === "string" ? value : JSON.stringify(value ?? "");
const blockText = blocks => (blocks || []).map(b => typeof b === "string" ? b : b.text || "").filter(Boolean).join("\n");
const digest = value => createHash("sha256").update(value).digest("hex");
export function sessionId(home, id) {
  const h = digest("codex-import:" + resolve(home) + ":" + id);
  return h.slice(0, 8) + "-" + h.slice(8, 12) + "-5" + h.slice(13, 16) +
    "-a" + h.slice(17, 20) + "-" + h.slice(20, 32);
}
export function projectDir(root, cwd) {
  return join(root, "--" + resolve(cwd).replace(/^[/\\]/, "").replace(/[/\\:]/g, "-") + "--");
}

export function displayName(source) {
  return (source.indexName || source.row?.name || source.row?.title || "Codex conversation")
    .replace(/[\r\n]+/g, " ").trim();
}

export function latestFamilies(sources) {
  const byId = new Map(sources.map(s => [s.id, s]));
  const groups = new Map();
  for (const source of sources) {
    let root = source.id;
    let node = source;
    const seen = new Set([root]);
    while (node.meta.forked_from_id && !seen.has(node.meta.forked_from_id)) {
      root = node.meta.forked_from_id;
      seen.add(root);
      node = byId.get(root);
      if (!node) break;
    }
    const key = source.cwd + ":" + root;
    const group = groups.get(key) || [];
    group.push(source);
    groups.set(key, group);
  }
  return [...groups.values()].map(group => group.sort((a, b) =>
    (b.row?.updated_at_ms || (b.row?.updated_at || 0) * 1000) -
      (a.row?.updated_at_ms || (a.row?.updated_at || 0) * 1000) ||
    Date.parse(b.meta.timestamp) - Date.parse(a.meta.timestamp) ||
    a.id.localeCompare(b.id)));
}

function readDb(path) {
  return existsSync(path) ? new DatabaseSync(path, { readOnly: true }) : undefined;
}
function walk(path) {
  if (!existsSync(path)) return [];
  return readdirSync(path, { withFileTypes: true }).flatMap(e => {
    const p = join(path, e.name);
    return e.isDirectory() ? walk(p) : /\.jsonl$/.test(e.name) ? [p] : [];
  });
}
async function firstMeta(file) {
  const stream = createReadStream(file);
  const lines = createInterface({ input: stream, crlfDelay: Infinity });
  try {
    for await (const line of lines) {
      if (!line.trim()) continue;
      const entry = JSON.parse(line);
      if (entry.type === "session_meta") return entry.payload;
      throw new Error("Missing session_meta: " + file);
    }
  } finally {
    lines.close();
    stream.destroy();
  }
}

export async function discover(homes) {
  const sources = [];
  for (const home of homes) {
    const names = new Map();
    const indexFile = join(home, "session_index.jsonl");
    if (existsSync(indexFile)) {
      for (const line of readFileSync(indexFile, "utf8").split("\n")) {
        if (!line.trim()) continue;
        let entry;
        try { entry = JSON.parse(line); } catch { continue; }
        const previous = names.get(entry.id);
        if (entry.thread_name && (!previous || Date.parse(entry.updated_at) >= Date.parse(previous.updated_at))) {
          names.set(entry.id, entry);
        }
      }
    }
    const db = readDb(join(home, "state_5.sqlite"));
    const indexed = db ? db.prepare("SELECT * FROM threads").all() : [];
    db?.close();
    const byPath = new Map(indexed.map(r => [resolve(r.rollout_path), r]));
    const files = new Set([
      ...walk(join(home, "sessions")), ...walk(join(home, "archived_sessions")),
      ...byPath.keys(),
    ]);
    const ids = new Map();
    for (const file of [...files].sort()) {
      if (!existsSync(file)) throw new Error("Indexed rollout missing: " + file);
      const meta = await firstMeta(file);
      if (!meta) throw new Error("Empty Codex file: " + file);
      const id = meta.id || meta.session_id;
      if (!id) throw new Error("Missing Codex thread ID: " + file);
      const row = byPath.get(resolve(file));
      const source = { home, file, id, cwd: row?.cwd || meta.cwd, meta, row,
        indexName: names.get(id)?.thread_name };
      if (!source.cwd) throw new Error("Missing source cwd: " + file);
      const previous = ids.get(id);
      if (previous && previous.file !== file) {
        throw new Error("Duplicate thread ID in distinct rollout files: " + id);
      }
      ids.set(id, source);
    }
    sources.push(...ids.values());
  }
  return sources;
}

// Prefer finalized UI messages, then completed items, then raw Responses items.
// These are parallel representations of the same turn, not separate replies.
export function selectRecords(records) {
  const ranks = new Map();
  for (const r of records) {
    if (!r.rank) continue;
    const key = r.turn + ":" + r.kind;
    ranks.set(key, Math.max(ranks.get(key) || 0, r.rank));
  }
  const seen = new Set();
  return records.filter(r => {
    if (r.rank && r.rank !== ranks.get(r.turn + ":" + r.kind)) return false;
    if (!r.dedup) return true;
    const key = r.turn + ":" + r.kind + ":" + r.dedup;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).sort((a, b) => a.ordinal - b.ordinal);
}

export async function parseSource(source) {
  const records = [];
  let ordinal = 0, turn = "initial", model = source.row?.model || "codex", provider = source.meta.model_provider;
  const counts = { rawLines: 0, encryptedReasoningSkipped: 0, invalidTailLines: 0, rollbackEvents: 0 };
  const completedIds = new Set();
  function add(kind, content, timestamp, options = {}) {
    if (content === undefined || content === null || content === "") return;
    records.push({ kind, content, timestamp, model, provider, turn, ordinal, ...options });
  }
  function completed(item, timestamp, rank = 2) {
    if (!item) return;
    const id = item.id;
    if (id && rank === 2) completedIds.add(id);
    const kind = item.type[0].toLowerCase() + item.type.slice(1);
    if (kind === "userMessage") {
      add("user", item.content, timestamp, { rank });
    } else if (kind === "agentMessage") {
      add("assistant", item.text || item.content, timestamp, { rank });
    } else if (kind === "reasoning") {
      const parts = item.summary_text || item.summary || item.raw_content || item.content || [];
      add("reasoning", Array.isArray(parts) ? parts.map(text).join("\n") : parts, timestamp, { rank });
    } else if (kind !== "contextCompaction") {
      add("tool", item, timestamp, { dedup: id || undefined });
    }
  }
  const stream = createReadStream(source.file, { end: statSync(source.file).size - 1 });
  let pendingInvalid;
  for await (const line of createInterface({ input: stream, crlfDelay: Infinity })) {
    if (!line.trim()) continue;
    if (pendingInvalid) throw new Error("Malformed interior JSONL line " + pendingInvalid + " in " + source.file);
    ordinal++;
    let entry;
    try { entry = JSON.parse(line); } catch { pendingInvalid = ordinal; continue; }
    counts.rawLines++;
    const p = entry.payload || {};
    const timestamp = entry.timestamp || source.meta.timestamp;
    if (entry.type === "turn_context") {
      turn = p.turn_id || turn; model = p.model || model; continue;
    }
    if (entry.type === "event_msg") {
      if (p.type === "task_started") turn = p.turn_id || "turn-" + ordinal;
      else if (p.type === "thread_settings_applied") {
        model = p.thread_settings?.model || model;
        provider = p.thread_settings?.model_provider_id || provider;
      } else if (p.type === "user_message") {
        const content = [{ type: "text", text: p.message || "" },
          ...(p.images || []).map(image => ({ type: "input_image", image_url: image })),
          ...(p.local_images || []).map(path => ({ type: "localImage", path }))];
        add("user", content, timestamp, { rank: 3 });
      } else if (p.type === "agent_message") add("assistant", p.message, timestamp, { rank: 3 });
      else if (p.type === "agent_reasoning") add("reasoning", p.text, timestamp, { rank: 3 });
      else if (p.type === "item_completed") {
        const item = p.item;
        turn = p.turn_id || turn;
        completed(item, timestamp);
      } else if (p.type === "thread_rolled_back") {
        counts.rollbackEvents++;
        add("notice", "Codex rolled back " + p.num_turns + " turn(s). Earlier text is retained here as historical transcript.", timestamp);
      }
    } else if (entry.type === "response_item") {
      if (p.type === "message" && ["user", "assistant"].includes(p.role)) {
        const contentText = blockText(p.content).trim();
        // Codex injects environment/AGENTS instructions with user role; Pi will
        // discover its own current environment and project instructions.
        const setup = p.role === "user" && (
          /^<environment_context>[\s\S]*<\/environment_context>$/.test(contentText) ||
          /^# AGENTS\.md instructions for /.test(contentText)
        );
        if (!setup) add(p.role, p.content, timestamp, { rank: 1 });
      } else if (p.type === "reasoning") {
        if (p.encrypted_content) counts.encryptedReasoningSkipped++;
        add("reasoning", blockText(p.summary) || blockText(p.content), timestamp, { rank: 1 });
      } else if (["function_call", "custom_tool_call", "function_call_output", "custom_tool_call_output", "web_search_call"].includes(p.type)) {
        add("raw_tool", p, timestamp, { dedup: p.type + ":" + (p.call_id || p.id || ordinal) });
      }
    } else if (entry.type === "compacted") {
      const summary = p.message || (p.replacement_history || [])
        .filter(x => x.type === "message" && ["user", "assistant"].includes(x.role))
        .map(x => blockText(x.content)).filter(Boolean).join("\n\n");
      add("compaction", summary, timestamp);
    }
  }
  if (pendingInvalid) counts.invalidTailLines++;

  // The projection DB can contain finalized items missing from a truncated tail.
  const history = readDb(join(source.home, "thread_history_1.sqlite"));
  if (history) {
    const items = history.prepare("SELECT turn_id,rollout_ordinal,created_at_ms,item_json FROM thread_items WHERE thread_id=? ORDER BY rollout_ordinal").all(source.id);
    for (const row of items) {
      const item = JSON.parse(row.item_json);
      if (completedIds.has(item.id)) continue;
      turn = row.turn_id;
      ordinal = row.rollout_ordinal + 0.5;
      completed(item, new Date(row.created_at_ms).toISOString(), 2);
    }
    history.close();
  }
  const selected = selectRecords(records);
  // UI events often retain only a local image path while raw Responses history
  // retains the original image bytes. Prefer those bytes for the same prompt.
  const rawImages = new Map();
  const imagesByTurn = new Map();
  for (const r of records) {
    if (r.kind !== "user" || r.rank !== 1 || !Array.isArray(r.content)) continue;
    const embedded = r.content.filter(b => typeof b.image_url === "string" && b.image_url.startsWith("data:image/"));
    if (embedded.length) rawImages.set(r.turn + ":" + blockText(r.content).trim(), embedded);
    if (embedded.length) {
      const turnImages = imagesByTurn.get(r.turn) || new Map();
      for (const image of embedded) turnImages.set(image.image_url, image);
      imagesByTurn.set(r.turn, turnImages);
    }
  }
  const usersByTurn = new Map();
  for (const r of selected.filter(r => r.kind === "user")) {
    usersByTurn.set(r.turn, (usersByTurn.get(r.turn) || 0) + 1);
  }
  for (const r of selected) {
    if (r.kind !== "user" || r.rank === 1) continue;
    const embedded = rawImages.get(r.turn + ":" + blockText(r.content).trim()) ||
      (usersByTurn.get(r.turn) === 1 && imagesByTurn.has(r.turn) ? [...imagesByTurn.get(r.turn).values()] : undefined);
    if (embedded) {
      r.content = [...r.content.filter(b => typeof b.text === "string"), ...embedded];
    }
  }
  // Completed command/file/search items already contain the tool output and are
  // portable across providers. Keep raw calls only where no UI item exists.
  const completedTools = new Set(selected.filter(r => r.kind === "tool").map(r => r.content.id));
  return {
    records: selected.filter(r => r.kind !== "raw_tool" ||
      (!completedTools.has(r.content.call_id) && !completedTools.has(r.content.id))),
    counts,
  };
}

function portableBlocks(content, counts) {
  if (typeof content === "string") return [{ type: "text", text: content }];
  return (content || []).flatMap(b => {
    if (typeof b === "string") return [{ type: "text", text: b }];
    if (typeof b.text === "string") return [{ type: "text", text: b.text }];
    if (["input_image", "image", "localImage", "local_image"].includes(b.type)) {
      const url = typeof b.image_url === "string" ? b.image_url : b.image_url?.url || b.url;
      const match = url?.match(/^data:(image\/[^;]+);base64,([\s\S]+)$/);
      if (match) { counts.images++; return [{ type: "image", mimeType: match[1], data: match[2] }]; }
      if (b.type === "image" && b.data && b.mimeType) {
        counts.images++; return [{ type: "image", data: b.data, mimeType: b.mimeType }];
      }
      if (b.path && existsSync(b.path) && /\.(png|jpe?g|webp|gif)$/i.test(b.path)) {
        const ext = b.path.split(".").at(-1).toLowerCase();
        const mimeType = "image/" + (["jpg", "jpeg"].includes(ext) ? "jpeg" : ext);
        counts.images++;
        return [{ type: "image", data: readFileSync(b.path).toString("base64"), mimeType }];
      }
      counts.imageReferences++;
      return [{ type: "text", text: "[Codex image reference: " + (b.path || url || "unavailable") + "]" }];
    }
    return [{ type: "text", text: "[Codex content: " + text(b) + "]" }];
  }).filter(b => b.type !== "text" || b.text);
}

export function makeEntries(source, parsed, defaults) {
  const id = sessionId(source.home, source.id);
  const created = new Date(source.meta.timestamp || (source.row?.created_at || 0) * 1000).toISOString();
  const counts = { ...parsed.counts, user: 0, assistant: 0, tools: 0, reasoning: 0, compactions: 0, images: 0, imageReferences: 0 };
  const entries = [{ type: "session", version: 3, id, timestamp: created, cwd: source.cwd }];
  let parentId = null;
  function add(entry, timestamp = created) {
    const entryId = digest(id + ":" + entries.length).slice(0, 16);
    entries.push({ ...entry, id: entryId, parentId, timestamp });
    parentId = entryId;
    return entryId;
  }
  add({ type: "custom", customType: "codex-import", data: {
    version: VERSION, sourceHome: source.home, threadId: source.id, rollout: source.file,
    provider: source.meta.model_provider, archived: Boolean(source.row?.archived),
  } });
  add({ type: "model_change", provider: defaults.defaultProvider, modelId: defaults.defaultModel });
  add({ type: "thinking_level_change", thinkingLevel: defaults.defaultThinkingLevel || "high" });
  add({ type: "session_info", name: displayName(source) });
  for (const r of parsed.records) {
    const timestamp = Number.isFinite(Date.parse(r.timestamp)) ? new Date(r.timestamp).toISOString() : created;
    const messageTime = Date.parse(timestamp);
    if (r.kind === "compaction") {
      const eid = digest(id + ":" + entries.length).slice(0, 16);
      add({ type: "compaction", summary: r.content, firstKeptEntryId: eid, tokensBefore: 0,
        details: { importedFrom: "codex" } }, timestamp);
      counts.compactions++;
      continue;
    }
    if (r.kind === "notice") {
      add({ type: "custom_message", customType: "codex-history", content: r.content, display: true }, timestamp);
      continue;
    }
    let content;
    if (r.kind === "user" || r.kind === "assistant") {
      content = portableBlocks(r.content, counts);
      if (!content.length) continue;
      counts[r.kind]++;
    } else if (r.kind === "reasoning") {
      content = [{ type: "thinking", thinking: text(r.content) }];
      counts.reasoning++;
    } else {
      const p = r.content;
      const portable = { ...p };
      // Retain tool arguments, output, and file diffs as a transcript, not as
      // pending tool calls which Pi could attempt to execute or validate.
      delete portable.internal_chat_message_metadata_passthrough;
      content = [{ type: "text", text: "[Codex tool history: " + (p.name || p.type) + "]\n" +
        JSON.stringify(portable, null, 2) }];
      counts.tools++;
    }
    if (r.kind === "user") {
      add({ type: "message", message: { role: "user", content, timestamp: messageTime } }, timestamp);
    } else {
      add({ type: "message", message: {
        role: "assistant", content, api: "openai-responses", provider: "codex-import",
        model: r.model || "codex", usage: zeroUsage(), stopReason: "stop", timestamp: messageTime,
      } }, timestamp);
    }
  }
  // Pi derives the startup model from the last assistant or model-change entry.
  // The historical model IDs need not exist in Pi's configured providers.
  const endTimestamp = entries.at(-1).timestamp;
  add({ type: "model_change", provider: defaults.defaultProvider, modelId: defaults.defaultModel }, endTimestamp);
  add({ type: "thinking_level_change", thinkingLevel: defaults.defaultThinkingLevel || "high" }, endTimestamp);
  return { entries, counts, id, created };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const reconcile = args.includes("--reconcile");
  if (args.some(x => !["--apply", "--dry-run", "--reconcile"].includes(x))) {
    throw new Error("Usage: pi-import-codex [--apply|--dry-run] [--reconcile]");
  }
  const piHome = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi/agent");
  const roots = [join(homedir(), ".codex"), join(homedir(), ".codex-deepseek")].filter(existsSync);
  const sessionsRoot = process.env.PI_CODING_AGENT_SESSION_DIR || join(piHome, "sessions");
  const defaults = JSON.parse(readFileSync(join(piHome, "settings.json"), "utf8"));
  if (!defaults.defaultProvider || !defaults.defaultModel) throw new Error("Pi default provider/model must be configured");
  const modulePath = process.env.PI_SESSION_MANAGER_MODULE;
  if (!modulePath) throw new Error("Missing PI_SESSION_MANAGER_MODULE (use the Nix wrapper)");
  const { SessionManager } = await import(pathToFileURL(modulePath));
  const importDir = join(piHome, "imports/codex");
  const manifestPath = join(importDir, "manifest.json");
  const manifest = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, "utf8")) :
    { version: VERSION, sessions: {} };
  const report = { startedAt: new Date().toISOString(), apply, roots, sessionsRoot, sessions: [], failures: [] };
  if (apply) mkdirSync(importDir, { recursive: true, mode: 0o700 });
  function privateJson(file, data) {
    const temp = file + ".tmp";
    const fd = openSync(temp, "w", 0o600);
    try { writeSync(fd, JSON.stringify(data, null, 2) + "\n"); } finally { closeSync(fd); }
    renameSync(temp, file);
  }
  const sources = await discover(roots);
  if (reconcile) {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const backupDir = join(importDir, "backups", stamp);
    const audit = { startedAt: new Date().toISOString(), renamed: [], hidden: [], retained: [], failures: [] };
    if (apply) {
      mkdirSync(backupDir, { recursive: true, mode: 0o700 });
      privateJson(join(backupDir, "manifest-before.json"), manifest);
    }
    for (const group of latestFamilies(sources)) {
      const winner = group[0];
      const winningImport = manifest.sessions[resolve(winner.home) + ":" + winner.id];
      if (!winningImport || winningImport.supersededBy || !existsSync(winningImport.destination)) {
        audit.failures.push({ threadId: winner.id, error: "Latest family member must be imported before reconciling" });
        continue;
      }
      for (const source of group) {
        const key = resolve(source.home) + ":" + source.id;
        const old = manifest.sessions[key];
        if (!old || old.supersededBy || !existsSync(old.destination)) continue;
        try {
          if (source !== winner) {
            const backup = join(backupDir, basename(old.destination));
            audit.hidden.push({ threadId: source.id, keptThreadId: winner.id, from: old.destination, backup });
            if (apply) {
              if (existsSync(backup)) throw new Error("Backup already exists: " + backup);
              renameSync(old.destination, backup);
              old.backup = backup;
              old.supersededBy = resolve(winner.home) + ":" + winner.id;
            }
          } else {
            const name = displayName(source);
            const manager = SessionManager.open(old.destination);
            if (manager.getSessionName() !== name) {
              audit.renamed.push({ threadId: source.id, from: manager.getSessionName(), to: name });
              if (apply) manager.appendSessionInfo(name);
            }
            audit.retained.push({ threadId: source.id, name, destination: old.destination });
            if (apply) old.name = name;
          }
          if (apply) privateJson(manifestPath, manifest);
        } catch (error) {
          audit.failures.push({ threadId: source.id, error: error.message });
        }
      }
    }
    if (apply) privateJson(join(importDir, "last-reconcile.json"), audit);
    console.log(JSON.stringify({ renamed: audit.renamed.length, hidden: audit.hidden.length,
      retained: audit.retained.length, failures: audit.failures, backupDir: apply ? backupDir : null,
      preview: apply ? undefined : { renamed: audit.renamed.slice(0, 3), hidden: audit.hidden } }, null, 2));
    if (audit.failures.length) process.exitCode = 1;
    return;
  }
  console.log("Found " + sources.length + " Codex sessions across " + new Set(sources.map(x => x.cwd)).size + " project directories");
  for (const source of sources) {
    const key = resolve(source.home) + ":" + source.id;
    const old = manifest.sessions[key];
    try {
      if (old?.supersededBy) {
        report.sessions.push({ ...old, status: "superseded" });
        continue;
      }
      if (old && existsSync(old.destination)) {
        if (apply && !old.startupModelChecked) {
          const manager = SessionManager.open(old.destination);
          if (manager.buildSessionContext().model?.provider === "codex-import") {
            manager.appendModelChange(defaults.defaultProvider, defaults.defaultModel);
            manager.appendThinkingLevelChange(defaults.defaultThinkingLevel || "high");
          }
          old.startupModelChecked = true;
          old.destinationBytes = statSync(old.destination).size;
          privateJson(manifestPath, manifest);
        }
        report.sessions.push({ ...old, status: "already-imported" });
        continue;
      }
      const snapshotBytes = statSync(source.file).size;
      const parsed = await parseSource(source);
      const converted = makeEntries(source, parsed, defaults);
      const dir = projectDir(sessionsRoot, source.cwd);
      const destination = join(dir, converted.created.replace(/[:.]/g, "-") + "_" + converted.id + ".jsonl");
      const record = { sourceHome: source.home, threadId: source.id, cwd: source.cwd,
        source: source.file, sourceBytes: snapshotBytes,
        destination, piId: converted.id, counts: converted.counts, archived: Boolean(source.row?.archived) };
      if (existsSync(destination)) throw new Error("Untracked destination already exists; refusing to overwrite: " + destination);
      if (apply) {
        mkdirSync(dir, { recursive: true, mode: 0o700 });
        const temp = destination + ".importing";
        const fd = openSync(temp, "wx", 0o600);
        try { for (const entry of converted.entries) writeSync(fd, JSON.stringify(entry) + "\n"); }
        finally { closeSync(fd); }
        const manager = SessionManager.open(temp);
        const context = manager.buildSessionContext();
        if (manager.getCwd() !== source.cwd || manager.getSessionId() !== converted.id) {
          throw new Error("Pi SDK rejected session identity or working directory");
        }
        const loaded = manager.getEntries();
        if (loaded.filter(x => x.type === "message" && x.message.role === "user").length !== converted.counts.user) {
          throw new Error("Pi SDK user-message count mismatch");
        }
        const expectedAssistant = converted.counts.assistant + converted.counts.tools + converted.counts.reasoning;
        if (loaded.filter(x => x.type === "message" && x.message.role === "assistant").length !== expectedAssistant) {
          throw new Error("Pi SDK assistant-message count mismatch");
        }
        record.contextMessages = context.messages.length;
        if (context.model?.provider !== defaults.defaultProvider || context.model?.modelId !== defaults.defaultModel) {
          throw new Error("Pi SDK selected an unavailable historical model");
        }
        record.startupModelChecked = true;
        record.destinationBytes = statSync(temp).size;
        renameSync(temp, destination);
        chmodSync(destination, 0o600);
        manifest.sessions[key] = record;
        privateJson(manifestPath, manifest);
      }
      report.sessions.push({ ...record, status: apply ? "imported" : "planned" });
      if (report.sessions.length % 10 === 0) console.log("Processed " + report.sessions.length + "/" + sources.length);
    } catch (error) {
      report.failures.push({ source: source.file, threadId: source.id, error: error.message });
      console.error("Failed " + source.id + ": " + error.message);
    }
  }
  report.finishedAt = new Date().toISOString();
  report.summary = {
    sessions: report.sessions.length, directories: new Set(report.sessions.map(x => x.cwd)).size,
    imported: report.sessions.filter(x => x.status === "imported").length,
    skipped: report.sessions.filter(x => x.status === "already-imported").length,
    superseded: report.sessions.filter(x => x.status === "superseded").length,
    failures: report.failures.length,
    totals: report.sessions.reduce((out, x) => {
      for (const [k, n] of Object.entries(x.counts)) out[k] = (out[k] || 0) + n;
      return out;
    }, {}),
  };
  if (apply) privateJson(join(importDir, "last-report.json"), report);
  console.log(JSON.stringify(report.summary, null, 2));
  if (report.failures.length) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
