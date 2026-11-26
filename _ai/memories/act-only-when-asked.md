---
name: act-only-when-asked
description: Questions get answers, not edits; commit only when asked; push,
  tag, MR changes and posting each need Kyle's explicit go-ahead
metadata:
  node_type: memory
  type: feedback
---

Do what the latest message asks, and keep everything local until Kyle says
otherwise.

## A question is not a change request

When Kyle asks why, how or whether, or asks to assess, review, justify,
opine or brainstorm, answer and stop. Do not edit, commit or amend along the
way. Offer the change in one line and wait for a yes.

## Local by default

- Commit only when asked ("commit", "commit as you go", "fix as one local
  commit"). Without that, leave changes uncommitted.
- Each of these needs Kyle's explicit go-ahead for that specific action:
  pushing, creating tags or releases, opening an MR, editing an MR title or
  description, posting MR or issue comments, updating tickets, and sending
  chat messages. A yes for one is not a yes for the next.
- Draft outward-facing text and show it before posting. Post the approved
  text exactly; Kyle often edits a draft before approving it.
- When Kyle says "I'll push" or "I will tag myself", leave that step alone.

**Why:** between Sep and Nov 2026 Kyle put these guards into about 22
prompts: "Don't make any changes, just tell me", "Don't fix yet, just
assess", "Don't do it, just opine", "DO NOT PUSH", "do not push / do not
open the MR yet", "Do not tag; I will tag myself", "Show it to me again
before posting". Actions that reach a remote, a ticket or a chat cannot be
quietly taken back.

**How to apply:** before an edit, check that the latest message asks for
one; before any command that leaves the machine, check that Kyle approved
that action in this conversation. Related: [[git-branching]],
[[agent-attribution]].
