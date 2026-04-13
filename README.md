# coreutils-ai

LLM-augmented CLI tools that follow a **deterministic-first, LLM-second** pattern. Shell commands gather facts, then a cheap/fast LLM (flash-lite) ranks, diagnoses, or summarizes the output.

All tools route through a configurable LLM backend via [simonw/llm](https://github.com/simonw/llm).

## Tools

### `relevant` — find files relevant to a task

```bash
relevant "fix the login bug"
relevant "add dark mode" ./src
```

Gathers file tree, filename matches, content grep, and recently modified files, then asks the LLM to rank them by relevance. Returns 5-15 files with one-line reasons.

### `why` — diagnose errors

```bash
npm install 2>&1 | why
cargo build 2>&1 | why
python3 app.py 2>&1 | why
```

Classifies the error (dependency, typecheck, permission, etc.), extracts the root cause, and suggests the exact next command to run.

### `diffsummary` — structured diff analysis

```bash
diffsummary              # staged + unstaged changes
diffsummary HEAD~3       # last 3 commits
git diff main | diffsummary  # piped diff
```

Produces a structured summary: files changed, behavior changes, API changes, risk areas, test coverage, and candidate commit titles.

### `lt` — tree with per-directory limits

```bash
lt           # current dir, 2 levels deep
lt /path 3   # custom path, 3 levels deep
```

Like `tree` but caps each directory at 30 entries, showing `... +N more` for the rest. No LLM — pure Python.

## Requirements

- [llm](https://github.com/simonw/llm) CLI with any model configured
- `tree`, `rg` (ripgrep) — for `relevant`
- `git` — for `diffsummary`
- Python 3 — for `lt`

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

## LLM setup

These tools call `llm` with whatever default model you've configured. Any backend works:

```bash
# Option 1: Gemini (cheapest for flash-lite)
llm install llm-gemini
llm keys set gemini
llm models default gemini-2.0-flash-lite

# Option 2: OpenAI
llm keys set openai
llm models default gpt-4o-mini

# Option 3: Local models via Ollama
llm install llm-ollama
llm models default llama3

# Option 4: Any OpenAI-compatible proxy (LiteLLM, vLLM, etc.)
# Add to ~/.config/io.datasette.llm/extra-openai-models.yaml:
#   - model_id: my-proxy
#     model_name: your-model
#     api_base: "https://your-proxy.example.com"
#     api_key_name: my-key
# Then: llm models default my-proxy
```

A fast, cheap model (flash-lite, gpt-4o-mini, llama3) is recommended. These tools don't need frontier intelligence — they need speed.

## Design philosophy

These tools are **not agents**. They don't loop, converse, or use tool calls. Each one is a single-shot pipeline:

1. **Shell gathers facts** — `tree`, `rg`, `find`, `git diff`, `ps`
2. **Pipe to LLM** — with a hardcoded system prompt
3. **LLM explains/ranks/compresses** — one inference call, ~1-3 seconds

The LLM never sees data it didn't get from deterministic shell commands, so it can't hallucinate file paths or invent errors.

## License

MIT
