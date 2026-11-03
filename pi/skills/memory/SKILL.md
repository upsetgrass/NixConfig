---
name: memory
description: Maintain pi's persistent file-based memory across sessions. Use when the user says "remember", "记住", "记一下", "以后都…", states a durable preference, rule, or constraint, corrects a previous assumption, records a project decision with rationale, or asks what you remember. Also use to audit, consolidate, or clean up MEMORY.md and its topic files.
---

# Memory

Pi has native persistent, file-based memory. This skill adds a disciplined
read / write / curation workflow. Memory is plain Markdown: read it with
`read`, edit it with `edit` / `write`.

## Locations

| Scope | Index | Topic files |
| --- | --- | --- |
| Global (this user, all projects) | `~/.pi/agent/memory/MEMORY.md` | `~/.pi/agent/memory/*.md` |
| Project (committed to the repo, shared) | `<repo>/.pi/memory/MEMORY.md` | `<repo>/.pi/memory/*.md` |

An index may not exist yet: create it with `write` on first save.

Choose the scope by audience:

- **Project** — build/test commands, architecture constraints, conventions,
  decisions and their rationale. Teammates should benefit.
- **Global** — user preferences, language/style, machine/environment quirks
  that apply across projects.
- When unsure, prefer project scope.

## When to write

Write in the **same turn** the fact is learned:

- The user says "remember", "记住", "记一下", "以后都用…", "别再…".
- The user corrects you: record the corrected fact **and** why the old one
  was wrong.
- A durable command or constraint is discovered (build, test, deployment,
  required environment variable, version pin).
- A decision is made and the rationale is non-obvious.
- A stable preference is expressed (language, formatting, workflow, tools).

Do **not** write:

- Secrets: passwords, tokens, API keys, private keys, credentials.
- Facts the repo already records: code structure, git history, `AGENTS.md`,
  README. Point at them instead.
- Transient task state ("currently editing X", "tests are running").
- Unverified guesses, or a single observation that may be noise.

## Workflow

1. **Read before writing.** Read the target `MEMORY.md` first so you update
   instead of duplicating.
2. **Deduplicate.** If a matching entry exists, edit it in place. Keep one
   canonical entry per fact.
3. **Split detail.** If the fact needs more than one line, create or append a
   topic file (e.g. `build.md`, `nix.md`, `preferences.md`) and leave a
   one-line pointer in `MEMORY.md`.
4. **Delete wrong entries.** If a fact is wrong, replace or remove it. Move
   merely stale (but historically useful) content to `archive/`.
5. **Keep the index short.** `MEMORY.md` is an index: one line per fact,
   grouped under `##` headings. No multi-paragraph essays.
6. **Verify.** Re-read `MEMORY.md`; confirm it is still concise, has no
   secrets, and no duplicate entries.

## Index format

```markdown
# Memory

## Environment
- Java 21 is required; `JAVA_HOME` must be set before `mill`.

## Build & test
- Full RTL build: `make verilog` (slow); compile-only check: `mill -i xiangshan.compile`.
- Build/test details: see [build.md](build.md).

## Decisions
- Keep generated RTL out of `src/main/scala`; it breaks `xiangshan.compile`.
```

Rules:

- One fact per line; start with the fact, not "The user said…".
- Group related lines under a `##` heading; create headings as needed.
- Put long explanations in topic files and link them as `[name](name.md)`.
- Include **why** only when it prevents a future mistake.
- Date entries only when the timing matters.

## Topic file format

```markdown
# Build & test

## Incremental compile
`mill -i xiangshan.compile` catches Scala errors in seconds.
Use it before a full `make verilog`, which also elaborates Chisel and
runs firtool.
```

## Recalling memory

At the start of a task, search instead of loading everything:

```bash
rg -n "keyword" ~/.pi/agent/memory <repo>/.pi/memory
```

Load only the topic files relevant to the task. When the user asks "what do
you remember?", read the applicable `MEMORY.md` and summarize; do not dump
entire files.

## Curation checklist

Run when memory grows or the user asks to clean it:

- [ ] Every index line still true?
- [ ] Duplicates merged?
- [ ] Long entries moved to topic files with links?
- [ ] Wrong entries deleted; stale ones moved to `archive/`?
- [ ] No secrets or credentials?
- [ ] No facts that belong in `AGENTS.md` or the README?
