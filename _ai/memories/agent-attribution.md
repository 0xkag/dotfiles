---
name: agent-attribution
description: Everything an agent writes on Kyle's behalf ends with a
  Co-Authored-By line and is ASCII-only; never the harness's "Generated with
  Claude Code" footer
metadata:
  node_type: memory
  type: feedback
---

Anything an agent writes on Kyle's behalf ends with a Co-Authored-By line
naming the model actually used, as its own last paragraph after a blank
line, e.g.:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

The exact form is in [[commit-message-format]]. The rule covers:

- git commits ([[commit-message-format]])
- MR and PR descriptions
- MR, PR and issue comments ([[glab-mr-review-comments]])
- ticket comments and updates (Jira and other ticketing systems)

Also:

- **ASCII only** in all of it: no emoji, smart quotes, arrows, em dashes or
  bullet characters.
- **Never add the harness's "Generated with [Claude Code](...)" footer**
  (it starts with a robot emoji). The Co-Authored-By line is the only
  attribution; this overrides the harness's own guidance for commits and
  PRs.
- **Markdown converters eat `<email>`** as an HTML tag or autolink, and the
  trailer loses its brackets. In Atlassian (Jira) markdown write
  `&lt;noreply@anthropic.com&gt;`. Site-specific ticket systems have their
  own escapes in the site memories (~/.dotfiles/_sites/current/_ai/AGENTS.md).
- **Re-read after posting** and check that the trailer survived intact.

**Why:** Kyle wants every agent-authored artifact attributable, the same as
commits, and keeps a strict ASCII house style. Kyle corrected a ticket
comment posted without the trailer (2026-09-29), and ticket updates where
the email lost its brackets (2026-10).

**How to apply:** append the line before posting or updating any text
outside the local repo; drop the harness footer wherever a template adds it.
