---
name: avoid-scratchpad-prefer-cwd
description: Do not keep working files in the /tmp scratchpad; a sandbox
  restart clears it. Prefer a directory under the CWD.
metadata:
  node_type: memory
  type: feedback
---

Avoid the session scratchpad (under /tmp) and /tmp in general for any file
later steps depend on. Prefer the current working directory, in a git-excluded
folder such as tmp/. Before updating remote state from a local file (an MR
description, for example), fetch the live value first.
