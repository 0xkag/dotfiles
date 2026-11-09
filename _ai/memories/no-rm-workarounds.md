---
name: no-rm-workarounds
description: rm is denied in Kyle's Claude Code settings; never delete
  another way, avoid intermediates, and ask Kyle to remove files
metadata:
  node_type: memory
  type: feedback
---

`rm` is denied in Kyle's Claude Code settings (`Bash(rm *)` in
~/.dotfiles/claude/settings.json). The deny is a deliberate boundary: do not
delete files another way, such as Python `os.remove` / `shutil.rmtree`,
`find -delete`, `unlink`, `git clean` or `tempfile.TemporaryDirectory`
cleanup.

- Prefer designs that never write intermediates: keep downloads and
  archives in memory, and write only final outputs.
- When something has to go, list the paths and sizes and ask Kyle to remove
  them, e.g. by running `! rm <path>`.

**Why:** "you'll have to ask me to remove intermediate data since your rm
is blocked" (2026-10-13).

**How to apply:** before writing scratch data, plan where it will live and
who removes it. Related: [[avoid-scratchpad-prefer-cwd]].
