#!/usr/bin/env bash
# MemPalace PreCompact hook — saves context before /compact wipes it
# Reads JSON from stdin (Claude Code hook format), outputs JSON to stdout

VENV="/home/joeyang/memory/.venv"
PALACE="/home/joeyang/memory/.mempalace/palace"

exec "$VENV/bin/mempalace" --palace "$PALACE" hook run --hook precompact --harness claude-code
