# coreutils-ai

> **Unix tools, augmented with LLM inference.** Find relevant files, diagnose errors, summarize diffs — in 1-3 seconds.

```bash
relevant "fix the login bug"           # → ranked list of files to look at
npm install 2>&1 | why                 # → root cause + exact fix command
diffsummary                            # → structured change summary + commit titles
```

**No agents. No loops. No conversations.** Each tool gathers facts with standard shell commands, pipes them to a cheap LLM, and prints a structured result.

---

## Tools

### `relevant` — find files relevant to a task

```bash
$ relevant "fix the login bug" ./src
src/auth/login.ts — handles credential exchange
src/middleware/session.ts — validates session tokens
tests/auth/login.test.ts — existing login test coverage
prisma/schema.prisma — user/session model definitions
```

How it works: runs `tree` + `find` (filename matching) + `rg` (content grep) + recently modified files, then asks the LLM to rank by relevance. Only returns files it actually found — never hallucinates paths.

### `why` — diagnose errors

```bash
$ python3 app.py 2>&1 | why
[dependency] The pandas library is not installed in the current environment.
Confidence: high
Fix: Install the missing dependency.
Run: pip install pandas
```

Classifies errors (dependency, typecheck, permission, port conflict, etc.), extracts the root cause (not the last noisy line), and gives you the exact next command to run.

### `diffsummary` — structured diff analysis

```bash
$ diffsummary HEAD~3
FILES CHANGED:
- auth.py: Replaced hardcoded login with hash-based credential check

BEHAVIOR CHANGES:
- Login now returns a token instead of a boolean

API CHANGES:
- login(): return type changed from bool to dict

RISK AREAS:
- Existing callers expecting bool from login() will break

COMMIT TITLE:
- Upgrade authentication to use hashed credentials
```

Works with: `diffsummary` (unstaged), `diffsummary HEAD~N` (commit range), `git diff branch | diffsummary` (piped).

### `lt` — tree with per-directory limits

```bash
$ lt /var/log
├── nginx/
│   ├── access.log
│   ├── error.log
│   └── ... +12 more
├── syslog
└── auth.log
```

Like `tree` but caps each directory at 30 entries. No LLM — pure Python.

---

## Install

```bash
git clone https://github.com/testy-cool/coreutils-ai.git
cd coreutils-ai

# Symlink into your PATH
for tool in relevant why diffsummary; do
  ln -sf "$(pwd)/$tool" ~/.local/bin/$tool
done
ln -sf "$(pwd)/lt.py" ~/.local/bin/lt.py
```

### Requirements

- [llm](https://github.com/simonw/llm) CLI with any model configured
- `tree`, `rg` (ripgrep) — for `relevant`
- `git` — for `diffsummary`
- Python 3 — for `lt`

### LLM setup

These tools call `llm` with whatever default model you've configured. Any backend works:

```bash
# Gemini (recommended — cheapest)
llm install llm-gemini && llm keys set gemini && llm models default gemini-2.0-flash-lite

# OpenAI
llm keys set openai && llm models default gpt-4o-mini

# Local via Ollama
llm install llm-ollama && llm models default llama3

# Any OpenAI-compatible proxy (LiteLLM, vLLM, etc.)
# See: https://llm.datasette.io/en/stable/other-models.html
```

A fast, cheap model is recommended. These tools don't need frontier intelligence — they need speed.

---

## Design

```
shell commands (tree, rg, find, git diff)
        │
        ▼
   deterministic facts (file lists, grep matches, diff text)
        │
        ▼
   LLM inference (rank, diagnose, summarize)
        │
        ▼
   structured output
```

**Deterministic-first, LLM-second.** The LLM never sees data it didn't get from shell commands, so it can't hallucinate file paths or invent errors. Each tool is a single `llm` call — no agents, no retries, no conversation state.

## License

MIT
