# ai-cli-utils

> **7 Unix tools, augmented with LLM inference.** Find relevant files, diagnose errors, summarize diffs, understand codebases, compress logs, inspect running processes — in 1-3 seconds.

```bash
relevant "fix the login bug"           # → ranked list of files to look at
npm install 2>&1 | why                 # → root cause + exact fix command
diffsummary                            # → structured change summary + commit titles
digest src/ "how does billing work"    # → targeted answer from codebase
journalctl --since "1h ago" | sumlog   # → anomalies + pattern summary
wtf :3000                             # → what's on port 3000
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

### `digest` — understand large files or directories via LLM

```bash
$ digest app.py
PURPOSE: Flask web app serving a REST API for user management
STACK: Python 3.11, Flask, SQLAlchemy, PostgreSQL
ENTRYPOINTS: app.py (gunicorn), cli.py (management commands)
KEY COMPONENTS:
- routes/users.py — CRUD endpoints for /api/users
- models/user.py — User model with role-based permissions
- middleware/auth.py — JWT validation on protected routes

$ digest app.py "where's the auth"
Auth is handled in middleware/auth.py. Every route decorated with
@require_auth calls validate_jwt(), which checks the Authorization
header against the HMAC secret in config.py. Token expiry is 24h.

$ digest src/ "how does billing work"
Billing flows through three files: routes/billing.py receives
Stripe webhooks, services/subscription.py manages plan changes,
and models/invoice.py tracks payment history. Monthly charges
are triggered by a cron job in tasks/billing_cycle.py.
```

Uses proxy-flash (larger context model) since it handles big inputs.

### `sumlog` — compress logs and surface anomalies

```bash
$ sumlog /var/log/syslog
TOP ANOMALIES:
1. [URGENT] OOM killer invoked 3 times (PIDs 4821, 4833, 4901) — system under memory pressure
2. [WARN] nginx worker crashed and respawned 12 times in 30min — check upstream timeouts
3. [INFO] 847 repeated cron entries collapsed — normal but noisy

PATTERN SUMMARY:
- 1,204 lines → 38 unique patterns
- 96% routine (cron, dhclient renewals, systemd slice management)
- 4% anomalous (OOM, nginx crashes, disk I/O errors)

$ journalctl --since "1h ago" | sumlog
TOP ANOMALIES:
1. [WARN] docker healthcheck failing for container redis-cache — 8 consecutive failures
2. [INFO] USB device disconnect/reconnect cycle on bus 002 — possibly loose cable

$ sumlog -n 500 /var/log/syslog
(analyzes last 500 lines only)
```

Deduplicates and pattern-collapses BEFORE the LLM call. Surfaces top 3-5 anomalies and flags urgent items.

### `wtf` — runtime inspector

```bash
$ wtf :3000
PORT 3000: node /home/user/app/server.js (PID 14229, user: deploy)
Listening on 0.0.0.0:3000 (TCP, LISTEN)
Started: 2 days ago — 142MB RSS, 0.3% CPU
This is a Node.js HTTP server. It's bound to all interfaces,
so it's accessible from the network, not just localhost.

$ wtf pid 1234
PROCESS 1234: postgres: writer process (PID 1234, user: postgres)
Part of PostgreSQL cluster, responsible for writing dirty buffers
to disk. Parent PID 1200 (postmaster). Running since boot, normal.

$ wtf service postgres
SERVICE postgresql.service: active (running) since 3 days ago
Main PID: 1200, 14 child processes (workers, writer, checkpointer)
Listening on: 127.0.0.1:5432
Memory: 248MB — healthy, no recent restarts or failures.

$ wtf path ./tmp/socket
PATH ./tmp/socket: Unix domain socket, type=STREAM
Owned by PID 8821 (gunicorn: master [app:create_app()])
3 connected peers — this is the gunicorn worker socket.
```

Auto-detects query type (bare number = pid, starts with `:` = port, file path = path, otherwise tries service). Gathers facts from ss/lsof/ps/systemctl first, then the LLM explains.

---

## Install

```bash
git clone https://github.com/testy-cool/ai-cli-utils.git
cd ai-cli-utils

# Symlink into your PATH
for tool in relevant why diffsummary digest sumlog wtf; do
  ln -sf "$(pwd)/$tool" ~/.local/bin/$tool
done
ln -sf "$(pwd)/lt.py" ~/.local/bin/lt.py
```

### Requirements

- [llm](https://github.com/simonw/llm) CLI with any model configured
- `tree`, `rg` (ripgrep) — for `relevant`
- `git` — for `diffsummary`
- `ss`, `lsof`, `ps`, `systemctl` — for `wtf`
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
