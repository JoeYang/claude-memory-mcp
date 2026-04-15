# Migrating MemPalace to a New Host

Copy your palace data and re-run setup on the target machine.

## What Gets Migrated

| File | Contains | Size (typical) |
|---|---|---|
| `.mempalace/palace/chroma.sqlite3` | All drawers, embeddings, vectors | ~1-50 MB |
| `.mempalace/palace/<uuid>/` | ChromaDB segment files | ~1-10 MB |
| `.mempalace/knowledge_graph.sqlite3` | Temporal KG (entities, relationships) | ~40 KB |
| `.mempalace/config.json` | Wing taxonomy + keywords | ~3 KB (tracked in git) |

## Steps

### 1. Export Data on Source Machine

```bash
cd ~/memory
tar czf mempalace-data.tar.gz \
  .mempalace/palace/ \
  .mempalace/knowledge_graph.sqlite3
```

### 2. Transfer to Target Machine

```bash
scp mempalace-data.tar.gz newhost:~/
```

### 3. Set Up the Repo on Target Machine

```bash
git clone git@github.com:JoeYang/claude-memory-mcp.git ~/memory
cd ~/memory
```

Follow [SETUP.md](SETUP.md) steps 2-6:

```bash
# Python venv
uv venv .venv --python 3.12
uv pip install mempalace --python .venv/bin/python

# Initialize palace directory
mkdir -p .mempalace/palace

# Register MCP server
claude mcp add mempalace -s user -- \
  ~/memory/.venv/bin/python \
  -m mempalace.mcp_server \
  --palace ~/memory/.mempalace/palace

# Add MEMPALACE_HOME env to ~/.claude.json (see SETUP.md step 5)
```

### 4. Restore Data

```bash
cd ~/memory
tar xzf ~/mempalace-data.tar.gz
```

### 5. Configure Hooks

Copy the hook entries into `~/.claude/settings.json` (see [SETUP.md](SETUP.md) step 6). Update paths if your home directory differs.

### 6. Update CLAUDE.md

Copy the MemPalace section into `~/.claude/CLAUDE.md` (see [SETUP.md](SETUP.md) step 8). Update paths if needed.

### 7. Verify

```bash
# Palace loaded
.venv/bin/mempalace --palace .mempalace/palace status

# Search works
.venv/bin/mempalace --palace .mempalace/palace search "test query"

# MCP connected
claude mcp list | grep mempalace
```

## Updating Paths

If your username or home directory differs on the target machine, update these locations:

| File | What to change |
|---|---|
| `.mempalace/config.json` | `palace_path` value |
| `hooks/mempal_save_hook.sh` | `VENV` and `PALACE` variables |
| `hooks/mempal_precompact_hook.sh` | `VENV` and `PALACE` variables |
| `~/.claude/settings.json` | Hook command paths |
| `~/.claude/CLAUDE.md` | Palace location, venv path |
| `~/.claude.json` | MCP server command and env paths |

## ChromaDB Version Compatibility

If the source and target machines have different ChromaDB versions, run the migration tool after restoring:

```bash
.venv/bin/mempalace --palace .mempalace/palace migrate
```

## Troubleshooting

**"No palace found" after restore:**
Check that `chroma.sqlite3` is inside `.mempalace/palace/` (not nested one level deeper from the tar extraction).

**Search returns no results:**
Run repair to rebuild the vector index:
```bash
.venv/bin/mempalace --palace .mempalace/palace repair
```

**MCP tools not loading:**
Restart Claude Code (both CLI and desktop). See the [config location lesson](SETUP.md#5-register-mcp-server-with-claude-code) — MCP servers go in `~/.claude.json`, not `~/.claude/settings.json`.
