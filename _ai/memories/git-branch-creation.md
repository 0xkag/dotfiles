---
name: git-branch-creation
description: Never create a git branch or worktree on Kyle's behalf — suggesting
one is welcome, but wait for him to ask before creating it
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
agrees. When he does ask for one, name it per [[git-branch-naming]] and note
that nvim work has its own constraint in [[dotfiles-nvim-no-worktree]].
