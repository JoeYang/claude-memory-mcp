#!/usr/bin/env bash
# MemPalace Stop hook — saves session context on session end
# Reads JSON from stdin (Claude Code hook format), outputs JSON to stdout

VENV="/home/joeyang/memory/.venv"
PALACE="/home/joeyang/memory/.mempalace/palace"

exec "$VENV/bin/mempalace" --palace "$PALACE" hook run --hook stop --harness claude-code
