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
  added, **always lower case, acronyms included** (e.g. `nginx:`,
  `dispatch:`, `ci:`, never `CI:`).
- Colon, single space, then an **Upper-case-initial** phrase. May be
  compounded with `;` (e.g. `appstart: Reload on config change; drain on
  stop`).
- NEVER use conventional-commit annotations like `fix()` / `feat()` / `chore:`
  — they are worthless. The free-form `topic:` prefix is the only prefix.
- NEVER put a ticket key in front (`TicketSystem#12345:`, `PROJ-123:`), even
  where other subjects in the repo do; the ticket goes in the body (see
  Trailers / references).
- **MR titles follow the same rules** as a subject line, ticket-key ban
  included; Kyle hates ticket keys in front of a title (2026-11-02).

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
- **No continuation line may start with `-`.** At column 0 it reads as a new
  `-- ` bullet. When the word that would start the line begins with `-` (a
  flag like `--force-with-lease`, a negative number), carry the word before
  it down too. This includes URL continuations: break after `/-/`, never
  before it.
- **Never split a hyphenated word** across lines (`get-ip-set` stays whole).
  `gq` never does this, but Python `textwrap` does unless
  `break_on_hyphens=False`.
- **No `-` or `--` as a dash** inside a statement; use `;` when the thoughts
  relate, or parentheses. Wrapped to column 0 it reads as a new bullet.
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

### Hyphens at a wrap, bad and good
```
bad: the flag lands at column 0 and reads as a new bullet
-- push the rebased branch with git push origin HEAD:refs/heads/x using
--force-with-lease=<branch>:<old-sha> so a concurrent push is kept

good: "using" is carried down with it
-- push the rebased branch with git push origin HEAD:refs/heads/x
using --force-with-lease=<branch>:<old-sha> so a concurrent push is kept

bad: textwrap split a hyphenated word (break_on_hyphens defaults to True)
-- sync the allow list from S3 on a cron so the WAF IP set follows the get-
ip-set output with no manual step

bad: a dash used as punctuation wrapped to column 0
-- keep the old nginx workers alive until the drain is done, bounded
-- not forever -- by worker_shutdown_timeout

good: ; instead of the dash
-- keep the old nginx workers alive until the drain finishes; bound the
drain with worker_shutdown_timeout so they cannot linger
```

### Wrapping by script
When wrapping by script instead of by hand, use this, then check the result:
```python
def bullet_wrap(text, width=75):
    """
    Greedy-fill one '-- ' bullet like vim gq: break only at spaces, and never
    start a continuation line with '-'.
    """
    lines, line = [], ['--']
    for word in text.split():
        if len(' '.join(line + [word])) <= width:
            line.append(word)
            continue
        carry = [word]
        while carry[0].startswith('-') and len(line) > (1 if lines else 2):
            carry.insert(0, line.pop())
        lines.append(' '.join(line))
        line = carry
    lines.append(' '.join(line))
    return lines

def bullet_check(lines, width=75):
    assert all(len(l) <= width and l.isascii() for l in lines), lines
    assert not any(l.startswith('-') or l.endswith('-') for l in lines[1:]), lines
```
A hyphen split in a pushed commit (2026-09-21) cost an amend and a
force-push on a branch under review.

## Multiple topics in one commit
- Group bullets by topic. Lead each block with a `topic:` heading followed by
  a blank line, then the block's `-- ` lines.
- A related block of `-- ` lines has **NO blank lines between the bullets**.

## Trailers / references (order matters, at the very end of the body)
References in context go at the **end of the body, BEFORE**
Co-Authored-By, and come in two kinds:
- **Work tickets** (issues in a work ticketing system): the short ID is the
  **last `-- ` bullet**, directly after the other bullets with no blank line,
  e.g. `-- TicketSystem#12345` or `-- PROJ-123`. Never a `Ref:` line for a
  ticket. In a multi-topic commit it ends the last block.
- **Links** (Slack messages and threads, GitLab MRs, anything else): a
  `Ref: <link>` line after a blank line, one per link. Write a GitLab MR in
  short form without the host: `Ref: group/sub/project!54`.
- If AI assisted with the commit, the message **ends with** a `Co-Authored-By`
  line naming the model actually used, in the form:
  `Co-Authored-By: <Provider> <Model> [Model Info Extra] <email>`.
  `<>` fields are required, `[]` fields are optional, `<email>` is always
  wrapped in a literal `<`/`>`, and adjacent whitespace is always collapsed to
  a single space (so if `[Model Info Extra]` is omitted, only one space sits
  between `<Model>` and `<email>`). E.g. `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>` or `Co-Authored-By: Claude Opus 4.8 (1M context)
  <noreply@anthropic.com>`.

## Blank-line rules
- One blank line between the Subject and the body (or first `topic:` heading).
- NO blank lines within a related block of `-- ` bullets.
- One blank line before a `topic:` heading and after it (before its bullets).
- One blank line between the last `-- ` bullet (the ticket bullet, if any)
  and the `Ref:` lines, and one between the `Ref:` lines and
  `Co-Authored-By`; no blank lines between consecutive `Ref:` lines.

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
-- TicketSystem#12345

Ref: https://example.slack.com/archives/X0XB7B71D7V/p1780329460545489
Ref: group/sub/project!54

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
-- TicketSystem#12345

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

**Why:** Kyle George maintains a specific, readable house style;
conventional-commit noise and unicode/soft-wrap drift make his history
inconsistent and harder to read in plain terminals.

**How to apply:** Draft the message, then check each line length (<=75 body,
<=56 subject), casing, ASCII-only, that no continuation line starts with `-`,
blank-line placement, and that refs + Co-Authored-By are last. My earlier
commits in these repos did NOT follow this — do not copy their style. See
[[agent-attribution]] for the Co-Authored-By rule on everything else written
on Kyle's behalf (MR descriptions and comments, tickets), and
[[git-history-rewrites]] for folding fix-ups into commits.
