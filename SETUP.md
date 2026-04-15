# MemPalace Setup Guide for Claude Code

A step-by-step guide to setting up [MemPalace](https://github.com/MemPalace/mempalace) as a cross-project memory system for Claude Code.

## Prerequisites

- Python 3.9+ (3.12 recommended)
- [uv](https://github.com/astral-sh/uv) (Python package manager)
- Claude Code CLI installed
- ~300 MB disk for the embedding model

## 1. Create the Repository

```bash
mkdir ~/memory && cd ~/memory
git init
git branch -m main
```

## 2. Set Up Python Virtual Environment

```bash
uv venv .venv --python 3.12
uv pip install mempalace --python .venv/bin/python
```

Create `pyproject.toml` for reproducibility:

```toml
[project]
name = "mempalace-config"
version = "0.1.0"
description = "MemPalace cross-project memory system for Claude Code"
requires-python = ">=3.12"
dependencies = [
    "mempalace",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

Create `.gitignore`:

```gitignore
# Python
.venv/
__pycache__/
*.pyc
*.egg-info/

# MemPalace data (large, local-only)
.mempalace/palace/
.mempalace/*.sqlite3
staging/
staging2/

# OS
.DS_Store
```

## 3. Initialize MemPalace

```bash
.venv/bin/mempalace --palace ~/memory/.mempalace/palace init ~/memory --yes
```

This creates a `mempalace.yaml` in the repo. The palace data directory is created when you first mine content.

## 4. Configure Wings

Create `.mempalace/config.json` with your wing taxonomy. Wings are broad categories; rooms form automatically within them via content clustering.

```json
{
  "palace_path": "/home/YOUR_USER/memory/.mempalace/palace",
  "collection_name": "mempalace_drawers",
  "topic_wings": [
    "technology",
    "science",
    "finance",
    "research",
    "people",
    "personal",
    "lessons",
    "decisions"
  ],
  "hall_keywords": {
    "technology": [
      "bazel", "cmake", "cpp", "java", "python", "rust", "typescript",
      "docker", "jni", "async", "mcp", "agent", "networking", "grpc",
      "trading", "exchange", "api", "database", "server", "protocol"
    ],
    "science": [
      "algorithm", "data structure", "complexity", "statistics",
      "machine learning", "optimization", "math"
    ],
    "finance": [
      "equity", "valuation", "stock", "portfolio", "risk", "macro",
      "earnings", "investment", "bond", "yield"
    ],
    "research": [
      "research", "analysis", "benchmark", "evaluation", "architecture",
      "design", "review", "deep dive", "comparison"
    ],
    "people": [
      "colleague", "mentor", "team", "manager", "collaborator",
      "contact", "engineer"
    ],
    "personal": [
      "preference", "workflow", "career", "learning", "certification",
      "style", "convention", "habit", "goal"
    ],
    "lessons": [
      "lesson", "mistake", "gotcha", "pitfall", "bug", "failure",
      "debugging", "root cause", "never again", "post-mortem"
    ],
    "decisions": [
      "decision", "chose", "tradeoff", "alternative", "revisit",
      "pros", "cons", "rationale", "rejected", "compromise"
    ]
  }
}
```

Adjust `palace_path` and keywords to match your needs.

## 5. Register MCP Server with Claude Code

```bash
claude mcp add mempalace -s user -- \
  /home/YOUR_USER/memory/.venv/bin/python \
  -m mempalace.mcp_server \
  --palace /home/YOUR_USER/memory/.mempalace/palace
```

Then manually add the env var to `~/.claude.json` under `mcpServers.mempalace.env`:

```json
"env": {
  "MEMPALACE_HOME": "/home/YOUR_USER/memory/.mempalace"
}
```

Verify:

```bash
claude mcp list  # Should show: mempalace: ... - ✓ Connected
```

> **Note:** After adding the MCP server, restart Claude Code (both CLI and desktop app) for tools to appear. The desktop app requires a full quit + reopen.

## 6. Set Up Auto-Save Hooks

Create `hooks/mempal_save_hook.sh`:

```bash
#!/usr/bin/env bash
# MemPalace Stop hook — saves session context on session end
VENV="/home/YOUR_USER/memory/.venv"
PALACE="/home/YOUR_USER/memory/.mempalace/palace"
exec "$VENV/bin/mempalace" --palace "$PALACE" hook run --hook stop --harness claude-code
```

Create `hooks/mempal_precompact_hook.sh`:

```bash
#!/usr/bin/env bash
# MemPalace PreCompact hook — saves context before /compact wipes it
VENV="/home/YOUR_USER/memory/.venv"
PALACE="/home/YOUR_USER/memory/.mempalace/palace"
exec "$VENV/bin/mempalace" --palace "$PALACE" hook run --hook precompact --harness claude-code
```

Make executable:

```bash
chmod +x hooks/mempal_save_hook.sh hooks/mempal_precompact_hook.sh
```

Add to `~/.claude/settings.json` under `hooks`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOUR_USER/memory/hooks/mempal_save_hook.sh",
            "statusMessage": "Saving session to MemPalace..."
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOUR_USER/memory/hooks/mempal_precompact_hook.sh",
            "statusMessage": "Saving context to MemPalace before compact..."
          }
        ]
      }
    ]
  }
}
```

> **Note:** If you already have hooks in `Stop`, append the MemPalace entry to the existing array — don't replace it.

## 7. Ingest Existing Memories

If you have existing Claude Code memory files:

```bash
# Copy with project prefixes to avoid name collisions
mkdir -p staging
for dir in ~/.claude/projects/*/memory/; do
  project=$(basename "$(dirname "$dir")")
  for f in "$dir"*.md; do
    [ -f "$f" ] && cp "$f" "staging/${project}__$(basename "$f")"
  done
done

# Mine into the palace
MEMPALACE_HOME=~/memory/.mempalace \
  .venv/bin/mempalace --palace ~/memory/.mempalace/palace \
  mine staging/ --mode convos
```

Verify:

```bash
.venv/bin/mempalace --palace ~/memory/.mempalace/palace search "your query here"
.venv/bin/mempalace --palace ~/memory/.mempalace/palace status
```

## 8. Add Rules to Global CLAUDE.md

Add to `~/.claude/CLAUDE.md`:

```markdown
## MemPalace (Cross-Project Memory)

MemPalace is the cross-project knowledge base backed by ChromaDB semantic search.
Built-in memory handles project-specific state. They are complementary, not competing.

**Palace location:** `/home/YOUR_USER/memory/.mempalace/palace`
**Venv:** `/home/YOUR_USER/memory/.venv`
**MCP server:** configured in ~/.claude.json as `mempalace`

### Wings (8)
| Wing | Purpose |
|---|---|
| technology | All tech: languages, build systems, trading infra, networking, protocols, agent workflow, tools |
| science | CS theory, algorithms, quantitative methods, machine learning |
| finance | Equity research, financial modeling, markets, macro/geopolitical |
| research | Deep dives, evaluations, competitive analysis, architecture reviews |
| people | Collaborators, contacts, relationships, who said what |
| personal | Preferences, career, learning goals, habits, conventions |
| lessons | Mistakes, gotchas, post-mortems — "never do X because Y happened" |
| decisions | Decisions made & rationale. Tag uncertain ones with "revisit" |

### Retrieval Triggers
When the user says any of the following, search MemPalace via MCP tools before answering:
- "remember last time...", "we did this before", "what was that command"
- "what did we learn about...", "that gotcha with..."
- "what was the decision on...", "why did we choose..."
- "have we seen this error before", "didn't we fix this"

### Session-End Save Rules
At session end (before /compact or closing):
1. Review what was learned this session
2. Save cross-project knowledge to MemPalace via MCP tools:
   - Technical knowledge → wing_technology
   - Mistakes/gotchas → wing_lessons
   - Decisions & tradeoffs → wing_decisions
   - People & relationships → wing_people
   - Personal preferences → wing_personal
3. Do NOT save project-specific state to MemPalace (use built-in memory for that)
4. For uncertain decisions, tag with "revisit" when saving to wing_decisions
```

## 9. Verify End-to-End

```bash
# Search works
.venv/bin/mempalace --palace ~/memory/.mempalace/palace search "test query"

# MCP server connected
claude mcp list | grep mempalace

# Palace status
.venv/bin/mempalace --palace ~/memory/.mempalace/palace status

# Hook scripts execute
echo '{}' | hooks/mempal_save_hook.sh
```

Start a new Claude Code session and verify:
- MCP tools appear (28 tools prefixed with `mempalace_`)
- Search works via MCP: ask Claude to search MemPalace
- Stop hook fires on session end

## Architecture

```
~/memory/                           # git repo
├── .gitignore
├── pyproject.toml                  # Python dependency declaration
├── mempalace.yaml                  # Project-level MemPalace config
├── SETUP.md                        # This file
├── .venv/                          # Python venv (gitignored)
├── .mempalace/
│   ├── config.json                 # Wing config with keywords
│   ├── palace/                     # ChromaDB data (gitignored)
│   └── knowledge_graph.sqlite3    # Temporal KG (gitignored)
└── hooks/
    ├── mempal_save_hook.sh         # Stop hook
    └── mempal_precompact_hook.sh   # PreCompact hook
```

## Key Concepts

- **Wings** — Broad categories (technology, lessons, decisions, etc.). Defined in `config.json`.
- **Rooms** — Sub-topics within wings. Created automatically by content clustering during `mempalace mine`.
- **Drawers** — Individual memory entries. Verbatim content stored in ChromaDB.
- **Halls** — Cross-wing memory corridors for facts, events, discoveries, preferences, and advice.
- **Knowledge Graph** — SQLite-backed temporal entity-relationship graph. Facts have `valid_from`/`valid_to` dates.
- **AAAK Compression** — 30x compression format for session summaries. AI-readable without custom decoders.
- **L0/L1 Boot** — ~170 tokens loaded at session start (identity + critical facts). L2/L3 retrieved on-demand.

## Useful Commands

```bash
# Search
.venv/bin/mempalace --palace .mempalace/palace search "query"

# Status
.venv/bin/mempalace --palace .mempalace/palace status

# Wake-up context (L0+L1)
.venv/bin/mempalace --palace .mempalace/palace wake-up

# Mine new content
.venv/bin/mempalace --palace .mempalace/palace mine /path/to/files
.venv/bin/mempalace --palace .mempalace/palace mine /path/to/chats --mode convos

# Repair (if ChromaDB corrupts)
.venv/bin/mempalace --palace .mempalace/palace repair
```

## MCP Tools (28)

| Tool | Purpose |
|---|---|
| `mempalace_search` | Semantic search across all wings/rooms |
| `mempalace_add_drawer` | Store verbatim content |
| `mempalace_diary_write` | AAAK-compressed session summary |
| `mempalace_kg_add` | Add entity relationships to knowledge graph |
| `mempalace_kg_query` | Query the temporal knowledge graph |
| `mempalace_list_wings` | List all wings |
| `mempalace_list_rooms` | List rooms in a wing |
| `mempalace_status` | Palace status overview |
| `mempalace_traverse` | Navigate wing → room → drawer |
| `mempalace_create_tunnel` | Cross-wing connections |
| ... | See `mempalace mcp` for full list |
