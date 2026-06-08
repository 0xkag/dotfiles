---
name: commit-message-format
description: "Kyle George's required git commit message format — subject
prefix/casing, -- body bullets, wrapping, issue refs, Co-Authored-By"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2c560b8d-566c-4256-a99d-647c33544fb7
---

Kyle George's commit message convention. Follow it for EVERY commit in his repos.

## Subject line
- Target **50 chars**, hard max **56**.
- Format: `topic: Phrase` where `topic` = the subsystem/topic changed or
  added, **lower case** unless it's an acronym (e.g. `nginx:`, `dispatch:`,
  `CI:`).
- Colon, single space, then an **Upper-case-initial** phrase. May be
  compounded with `;` (e.g. `appstart: Reload on config change; drain on
  stop`).
- NEVER use conventional-commit annotations like `fix()` / `feat()` / `chore:`
  — they are worthless. The free-form `topic:` prefix is the only prefix.

## Body
- Each statement is its own bullet starting with `-- ` (two dashes).
- **Wrap exactly like vim `gq` with `textwidth=75`: GREEDY FILL.** Pack each
  line with as many whole words as fit within 75 columns; break only at a word
  boundary, and only when the next word would exceed 75. Do NOT break early /
  leave lines short — body lines should routinely run 70-74 chars. (A common
  mistake is wrapping a word down a line before column 75 is actually
  reached.)
- 75 is the hard max; no line exceeds it.
- Wrapped continuation lines go to **column 0** — NO leading space/indent.
- Each `-- ` statement is **all lower case** except proper acronyms.
- Use `;` for punctuation within a statement when it relates; if a thought
  does NOT relate, put it on its own `-- ` line instead of joining with `;`.
- **ASCII only** — never any unicode characters (no smart quotes, arrows, em
  dashes, bullets). Plain ASCII UTF-8.
- URLs: put a URL on ONE line whenever the whole line fits within 75 chars
  (most refs do — do not break them). ONLY when a URL line would exceed 75 do
  you wrap it: end the line with `\` to mark continuation and break at a
  sensible URL atom/delimiter (e.g. right after the `?` before the query
  string, or after a `/`). The continuation line starts at column 0.
- Content is **scaled to scope/complexity** — a tricky change or hard-won
  finding gets a fuller explanation; a trivial change stays short.

## Multiple topics in one commit
- Group bullets by topic. Lead each block with a `topic:` heading followed by
  a blank line, then the block's `-- ` lines.
- A related block of `-- ` lines has **NO blank lines between the bullets**.

## Trailers / references (order matters, at the very end of the body)
- If a Slack / ArcTech / Jira / GitHub / GitLab issue or MR is in context,
  include it at the **end of the body, BEFORE** Co-Authored-By.
- If AI assisted with the commit, the message **ends with** a `Co-Authored-By`
  line.

## Blank-line rules
- One blank line between the Subject and the body (or first `topic:` heading).
- NO blank lines within a related block of `-- ` bullets.
- One blank line before a `topic:` heading and after it (before its bullets).
- One blank line between the last `-- ` bullet (and any ref line) and
  `Co-Authored-By`.

## Example (single topic)
Note the body lines are filled near column 75 (greedy `gq`), and the `Ref:`
URL sits on ONE line because the whole line is <=75 chars.
```
appstart: Reload nginx gracefully on config change

-- run a background reloader that calls stuff-reload on an interval so
config changes apply via nginx -s reload without a restart, liveness
checked in the monitor loop
-- bound worker drain with worker_shutdown_timeout so old workers do not
linger behind the long proxy and keepalive timeouts

Ref: https://example.slack.com/archives/X0XB7B71D7V/p1780329460545489

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
Only when a URL line would exceed 75 do you wrap it with `\`, e.g.:
```
Ref: https://gitlab.com/example/internal/some/very/long/project/path/-/\
merge_requests/1234
```

## Example (multiple topics)
```
deploy: Roll per-host; skip unchanged hosts

rolling:

-- release one host at a time, primaries then secondaries, halting on the
first failure so a bad release cannot roll across the whole pod

no-op:

-- add --skip-if-unchanged: skip a host when its app-declared files are
byte-identical to the currently-deployed artifact

TicketSystem#12345

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

**Why:** Kyle George maintains a specific, readable house style;
conventional-commit noise and unicode/soft-wrap drift make his history
inconsistent and harder to read in plain terminals.

**How to apply:** Draft the message, then check each line length (<=75 body,
<=56 subject), casing, ASCII-only, blank-line placement, and that refs +
Co-Authored-By are last. My earlier commits in these repos did NOT follow this
— do not copy their style. See [[glab-mr-review-comments]] for the related
rule that agent-written MR comments also end with Co-Authored-By.
