---
name: git-branching
description: Never create a git branch or worktree on Kyle's behalf;
  suggesting one is welcome, but wait for Kyle to ask. Name a requested
  branch with a plain kebab-case slug and no feature/ (or other) prefix
metadata:
  node_type: memory
  type: feedback
---

Do NOT create git branches or worktrees unless Kyle explicitly asks for one.
Work on, and commit to, whatever branch the repo is already on — including
`master` / `main`. This overrides the Claude Code built-in default of "if on
the default branch, branch first"; that default does not apply to Kyle's repos.

Suggesting is encouraged. Whenever a branch or worktree looks like the right
move (risky refactor, parallel lines of work, something he may want to abandon
cleanly, a change that wants its own MR), say so and say why — then wait for a
yes. The rule is about not acting unilaterally, not about staying quiet.

**Why:** unrequested branches and worktrees add cleanup he did not ask for and
silently relocate work away from where he expects to find it. Agents have also
repeatedly justified auto-branching by claiming his memories require it — they
do not, and never did.

**How to apply:** default to the current branch. If a branch or worktree seems
warranted, propose it in one line and continue on the current branch unless he
agrees. When he does ask for one, name it as below. Repo memories can add
limits, e.g. a repo where tests run in a worktree load the main checkout.

## Naming

Name a branch with a plain, descriptive, kebab-case slug and NO prefix.

- Do: `git checkout -b s3-perishable-and-replicated-pair`
- Don't: `git checkout -b feature/s3-perishable-and-replicated-pair`

Kyle does not want a `feature/` prefix (or similar `bugfix/` / `chore/`
prefixes) — he renamed a `feature/`-prefixed branch an agent created.
