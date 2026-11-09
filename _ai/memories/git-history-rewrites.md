---
name: git-history-rewrites
description: Kyle's commit hygiene (one complete change per commit, fix-ups
  folded in, bump last) and how to rewrite history safely
metadata:
  node_type: memory
  type: feedback
---

Each commit is one complete change: the code and its tests together. A
version bump commit, with its changelog, stays last. When a fix-up, review
fix or "correct the note" commit belongs to an earlier commit, propose
folding it in rather than leaving a follow-up commit; Kyle regularly asks
for exactly that, and for squash and reorder proposals before an MR goes
out.

## Before rewriting

- Unpushed history: fold once Kyle agrees.
- Pushed branch or MR under review: confirm first; a force-push resets
  reviewers' diffs and review bots' state.
- Someone else's MR: do not rewrite their commits; see
  [[gitlab-mr-patch-comments]].
- Record the old HEAD sha. Create a backup branch only when Kyle asks for
  one ([[git-branch-creation]]).

## Doing it

Interactive rebase works when no editor has to open. Write the todo list to
a file, then:

```
GIT_SEQUENCE_EDITOR="cp /abs/path/todo" GIT_EDITOR=true git rebase -i --autostash <base>
```

Use `fixup` for a fold, followed by an `exec git commit --amend -q -F
<msgfile>` line to install the merged message (per
[[commit-message-format]]). `--autostash` carries Kyle's unrelated
uncommitted files. Before reordering, check that the commits commute by
comparing `git show -U0 <c> -- <file> | grep ^@@` hunk ranges. Use `git -C`
or absolute paths; a `cd` into a subdirectory breaks later `git add` paths.

## After

- For a pure fold or reorder, `git diff <old-head> HEAD` must be empty:
  byte-for-byte the same result.
- Run the tests on the final tree, and per commit when each commit must
  stand alone.
- Push only with Kyle's go-ahead ([[act-only-when-asked]]), using
  `git push --force-with-lease=<branch>:<old-sha> origin <branch>`.

**Why:** Kyle had review fixes folded into the feature commit they tested,
then the tests commit squashed into it ("Both are for the 304 issue"),
asked for "all changelogs into the bump commit", wanted folds whose "End
result should be byte-for-byte the same", and asked for squash or reorder
proposals in at least five sessions between Sep and Nov 2026.

**How to apply:** when review fixes land, ask "fold into <sha> or a
follow-up commit?" with a recommendation. Repo memories can add limits,
e.g. a repo whose live config cannot survive checking out old commits.
