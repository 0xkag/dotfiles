---
name: copy-pastable-commands
description: When giving Kyle a shell command to run, wrap it at 78 columns
  with backslash continuations so it pastes as one command
metadata:
  node_type: memory
  type: feedback
---

When giving Kyle a shell command to run himself, keep every line within 78
columns. Break a long command between arguments, end each broken line with
` \` and indent the continuation lines by two spaces, so the block pastes
into a terminal as one command:

```
git push --force-with-lease=my-branch:0123abc \
  origin my-branch
```

- Nothing may follow the `\`, not even a space; otherwise the line ends
  the command there.
- Never break inside a quoted string, URL or path: a `\` before a newline
  inside single quotes is kept literally. When a path alone makes a line
  too long, put it in a variable on its own line first.
- Separate commands go on separate lines, not joined with `\`.

**Why:** Kyle asked for this on 2026-11-19; long single-line commands wrap
in his terminal and are awkward to copy and paste.

**How to apply:** check the line lengths of every command block meant for
Kyle before sending it.
