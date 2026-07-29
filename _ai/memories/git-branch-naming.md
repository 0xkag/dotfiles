---
name: git-branch-naming
description: How to name a git branch when Kyle asks for one — plain
descriptive slug, no feature/ (or other) prefix
metadata:
  node_type: memory
  type: reference
---

When creating a git branch — which you do ONLY when Kyle asks, see
[[git-branch-creation]] — name it with a plain, descriptive, kebab-case slug
and NO prefix.
Do: `git checkout -b s3-perishable-and-replicated-pair`
Don't: `git checkout -b feature/s3-perishable-and-replicated-pair`

Kyle does not want a `feature/` prefix (or similar `bugfix/` / `chore/`
prefixes) — he renamed a `feature/`-prefixed branch an agent created.
