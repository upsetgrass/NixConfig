import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { parseSource, makeEntries, selectRecords, projectDir, sessionId, displayName, latestFamilies } from "./import-codex.mjs";

test("current UI name wins over initial prompt and legacy database titles", () => {
  assert.equal(displayName({ indexName: "frontend scala code",
    row: { title: "old initial question" } }), "frontend scala code");
  assert.equal(displayName({ row: { name: "Renamed", title: "old" } }), "Renamed");
});

test("fork families retain the most recently updated history rather than newest fork creation", () => {
  const base = { cwd: "/project", meta: { timestamp: "2026-01-01T00:00:00Z" } };
  const old = { ...base, id: "old-fork", meta: { ...base.meta, forked_from_id: "missing-root" }, row: { updated_at: 1 } };
  const active = { ...base, id: "active", meta: { ...base.meta, forked_from_id: "old-fork" }, row: { updated_at: 10 } };
  const laterFork = { ...base, id: "later-fork", meta: { timestamp: "2026-02-01T00:00:00Z", forked_from_id: "missing-root" }, row: { updated_at: 2 } };
  const independent = { ...base, id: "unrelated", row: { updated_at: 20, title: "same title" } };
  const groups = latestFamilies([old, active, laterFork, independent]);
  assert.equal(groups.length, 2);
  assert.deepEqual(groups.find(g => g.length === 3).map(x => x.id), ["active", "later-fork", "old-fork"]);
});

test("message selection removes duplicate wire records without deleting repeated user turns", () => {
  const records = [
    { turn: "a", kind: "user", rank: 1, content: "again", ordinal: 1 },
    { turn: "a", kind: "user", rank: 3, content: "again", ordinal: 2 },
    { turn: "a", kind: "assistant", rank: 1, content: "OK", ordinal: 3 },
    { turn: "a", kind: "assistant", rank: 2, content: "OK", ordinal: 4 },
    { turn: "b", kind: "user", rank: 3, content: "again", ordinal: 5 },
    { turn: "b", kind: "assistant", rank: 3, content: "OK", ordinal: 6 },
  ];
  assert.deepEqual(selectRecords(records).map(x => x.ordinal), [2, 4, 5, 6]);
});

test("legacy and paginated records retain messages, images, tools and pre-compaction history", async () => {
  const home = mkdtempSync(join(tmpdir(), "pi-codex-import-test-"));
  const file = join(home, "rollout.jsonl");
  const cwd = "/tmp/a-project/subdir";
  const meta = { id: "source-id", cwd, timestamp: "2026-01-01T00:00:00.000Z", model_provider: "OpenAI" };
  const lines = [
    { type: "session_meta", payload: meta },
    { type: "event_msg", payload: { type: "task_started", turn_id: "one" } },
    { type: "response_item", payload: { type: "message", role: "user", content: [
      { type: "input_text", text: "Inspect this" },
      { type: "input_image", image_url: "data:image/png;base64,YQ==" },
    ] } },
    { type: "event_msg", payload: { type: "item_completed", turn_id: "one", item: {
      type: "UserMessage", id: "u1", content: [{ type: "text", text: "Inspect this" }, { type: "local_image", path: "/missing.png" }],
    } } },
    { type: "response_item", payload: { type: "message", role: "assistant", content: [{ type: "output_text", text: "I will inspect it" }] } },
    { type: "event_msg", payload: { type: "item_completed", turn_id: "one", item: {
      type: "AgentMessage", id: "a1", content: [{ type: "Text", text: "I will inspect it" }],
    } } },
    { type: "response_item", payload: { type: "function_call", call_id: "call1", name: "exec", arguments: '{"cmd":"pwd"}' } },
    { type: "response_item", payload: { type: "function_call_output", call_id: "call1", output: "/tmp/a-project" } },
    { type: "compacted", payload: { message: "The user asked to inspect an image." } },
    { type: "event_msg", payload: { type: "task_started", turn_id: "two" } },
    { type: "event_msg", payload: { type: "user_message", message: "Next", images: [], local_images: [] } },
    { type: "event_msg", payload: { type: "agent_message", message: "Done" } },
  ].map((x, i) => ({ ...x, timestamp: new Date(Date.parse(meta.timestamp) + i * 1000).toISOString() }));
  writeFileSync(file, lines.map(x => JSON.stringify(x)).join("\n") + "\n");
  const source = { home, file, id: meta.id, meta, cwd };
  const parsed = await parseSource(source);
  const result = makeEntries(source, parsed, { defaultProvider: "ai901", defaultModel: "model" });
  assert.equal(result.counts.user, 2);
  assert.equal(result.counts.assistant, 2);
  assert.equal(result.counts.images, 1);
  assert.equal(result.counts.tools, 2);
  assert.equal(result.counts.compactions, 1);
  assert.equal(result.entries[0].cwd, cwd);
  assert.equal(result.entries.at(-2).type, "model_change");
  assert.equal(result.entries.at(-2).provider, "ai901");
  const compaction = result.entries.find(x => x.type === "compaction");
  assert.equal(compaction.id, compaction.firstKeptEntryId);
  assert.equal(result.entries.filter(x => x.message?.role === "user").length, 2);
  for (let i = 2; i < result.entries.length; i++) {
    assert.equal(result.entries[i].parentId, result.entries[i - 1].id);
  }
  assert.equal(result.id, sessionId(home, meta.id));
  assert.notEqual(result.id, sessionId(home + "-other", meta.id));
  assert.equal(projectDir("/sessions", cwd), "/sessions/--tmp-a-project-subdir--");
});

test("truncated tail is reported, interior corruption is rejected", async () => {
  const home = mkdtempSync(join(tmpdir(), "pi-codex-tail-test-"));
  const file = join(home, "rollout.jsonl");
  const meta = { id: "source-id", cwd: home, timestamp: "2026-01-01T00:00:00.000Z" };
  const source = { home, file, id: meta.id, meta, cwd: home };
  writeFileSync(file, JSON.stringify({ type: "session_meta", payload: meta }) + '\n{"partial":');
  assert.equal((await parseSource(source)).counts.invalidTailLines, 1);
  writeFileSync(file, '{"invalid":\n' + JSON.stringify({ type: "session_meta", payload: meta }) + "\n");
  await assert.rejects(parseSource(source), /Malformed interior/);
});
