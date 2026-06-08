---
name: glab-mr-review-comments
description: How to find a GitLab MR and read/reply to inline + summary review
comments (from humans or review bots) and retrigger a re-review via glab
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2c560b8d-566c-4256-a99d-647c33544fb7
---

Reading and responding to a code reviewer's feedback on a GitLab MR via
`glab`.

Reviewer could be a human or a bot.  Bots might leaves inline comments + a
"Code Review Summary" with a NEEDS_WORK/APPROVE recommendation in a
semi-structured way.

## 1. Find the MR (resolve project by PATH, not a remembered numeric id)

**Gotcha that bit me:** MR IIDs collide across projects (`!47` exists in many
repos). A numeric project id I "remember" may be the wrong repo. Always
resolve from the project path, then confirm the MR's title/author/branch match
before acting.

```
enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "group/sub/project")
glab api "projects/$enc" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])"   # -> PROJECT_ID
glab api "projects/PROJECT_ID/merge_requests/IID" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['title'],d['source_branch'],d['author']['username'],d['sha'][:8])"
```

## 2. Read the feedback

- All notes (summary + system events): `glab api
  "projects/PROJECT_ID/merge_requests/IID/notes?sort=asc&per_page=100"`
- Discussions (needed for the **thread/discussion id** to reply to): `glab api
  "projects/PROJECT_ID/merge_requests/IID/discussions?per_page=100"`
- **Inline vs summary:** a note's first note has a `position` object (with
  `new_path`/`new_line`) ⇒ it's an **inline** comment on a code line. No
  `position` and `system:false` ⇒ a **summary / top-level** comment.
  `system:true` ⇒ ignore (commit-added, mentioned-in, etc.).
- **CRITICAL - never truncate the discussion id (this has bitten me twice).**
  The real `discussion.id` is a **40-char SHA-1 hex** (e.g.
  `66b582a26568935e53a00fbe15814e1dfaa17812`). When summarizing discussions,
  it is tempting to print `disc['id'][:12]` for readability - DO NOT do that
  and then paste the short form into the reply URL: `POST
  .../discussions/<12-char>/notes` returns **404 Discussion Not Found**. When
  iterating to summarize, print the FULL id (or keep a dict mapping a label ->
  full id), and pass the full 40-char id verbatim to the reply call. If you
  only have a truncated id, re-fetch `discussions?per_page=100` and grep the
  full id by matching note body text.

## 3. Reply IN-THREAD (not a new top-level comment)

Reply to the specific discussion so it threads under the finding. **Every
agent-written GitLab comment MUST end with a `Co-Authored-By` line** (blank
line before it), so comments authored by the agent are attributable — same as
commit/PR convention:

```
glab api --method POST "projects/PROJECT_ID/merge_requests/IID/discussions/DISCUSSION_ID/notes" -f "body=Fixed in <sha>. <what changed>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

This applies to ALL agent-generated MR comments (inline replies,
summary-thread replies, re-review pings, and any new top-level comment), not
just review responses. Reply to the summary thread the same way (use its
discussion id). Be factual: cite the fix + commit sha; no performative thanks.
If you disagree with a finding, push back with reasoning (e.g. I corrected a
code review bot suggestion that referenced `result.stdout`/`.stderr` when the
real attrs were `.output`/`.error`).

## 4. Update MR title/description (e.g. when scope changed)
```
glab mr update IID --title "..." --description "$(cat /tmp/body.md)"   # run from inside the repo, or pass -R group/sub/project
```

## 5. Retrigger any code revierw bots for a re-review

If the code review appears to be automated, try @ mentioning the bot and
asking nicely for a re-review.

See also [site-specific instructions](~/.dotfiles/_sites/current/_ai/memories/code-review-bot.md).

## Notes
- bash `cd` does NOT persist across separate Bash tool calls — `cd repo && git
  push` in ONE call, or pass `-R group/sub/project` to glab.
- After pushing review fixes, prefer a **follow-up commit** over `git commit
  --amend` + force-push on a branch already under review (amend/force-push
  disrupts the reviewer's diff view). Use the follow-up to also fix a flagged
  commit-subject if needed.
- glab is authed via `GITLAB_TOKEN` as Kyle George's user.
- For setting merge-order dependencies between MRs, see
  [[gitlab-mr-dependencies]]. 
