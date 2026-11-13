#!/usr/bin/env bash
# Run from anywhere; operates on the repo root.
cd "$(dirname "$0")/.." || exit 1
status=0
for f in TrackerBuddy/*.lua; do
  luac5.1 -p "$f" || status=1
done
for t in tests/test_core.lua tests/test_ui_smoke.lua; do
  [ -f "$t" ] || continue
  lua5.1 "$t" || status=1
done
exit $status
