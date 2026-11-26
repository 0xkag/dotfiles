---
name: glab-mr-review-comments
description: How to find a GitLab MR and read/reply to inline + summary review
  comments (from humans or review bots) and retrigger a re-review via glab
metadata:
  node_type: memory
  type: reference
---

Reading and responding to a code reviewer's feedback on a GitLab MR via
`glab`.

Reviewer could be a human or a bot.  Bots might leave inline comments + a
"Code Review Summary" with a NEEDS_WORK/APPROVE recommendation in a
semi-structured way.

## 1. Find the MR (resolve project by PATH, not a remembered numeric id)

**Gotcha:** MR IIDs collide across projects (`!47` exists in many
repos). A remembered numeric project id may be the wrong repo. Always
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
- **From a note link** (`.../merge_requests/IID#note_NOTE_ID`), find the
  thread holding that note; `--paginate` emits one array per page, so slurp
  and merge them:
  ```
  glab api --paginate "projects/PROJECT_ID/merge_requests/IID/discussions?per_page=100" \
    | jq -s --argjson n NOTE_ID 'add | map(select(any(.notes[]; .id == $n)))'
  ```
- **Inline vs summary:** a note's first note has a `position` object (with
  `new_path`/`new_line`) ⇒ it's an **inline** comment on a code line. No
  `position` and `system:false` ⇒ a **summary / top-level** comment.
  `system:true` ⇒ ignore (commit-added, mentioned-in, etc.).
- **CRITICAL - never truncate the discussion id (this has gone wrong twice).**
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

**Check `resolved` first.** A reply in a resolved discussion is collapsed
with it in the MR view, so Kyle cannot see it: a bot re-review request
posted in a long-resolved summary thread went missing this way
(2026-10-30). If the target discussion's notes have `resolved: true`, say
so, then either unresolve it with Kyle's OK (`glab api -X PUT
"projects/PROJECT_ID/merge_requests/IID/discussions/DISCUSSION_ID" -f
resolved=false`) or post where it is visible. Report a direct link to the
note you posted and to any bot reply.

Reply to the specific discussion so it threads under the finding. Every
agent-written comment of any kind (inline reply, summary-thread reply,
re-review ping, new top-level comment) ends with the `Co-Authored-By` line
after a blank line; the rule is in [[agent-attribution]]:

```
glab api --method POST "projects/PROJECT_ID/merge_requests/IID/discussions/DISCUSSION_ID/notes" -f "body=Fixed in <sha>. <what changed>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

Reply to the summary thread the same way (use its discussion id). Be
factual: cite the fix + commit sha; no performative thanks. If you disagree
with a finding, push back with reasoning (e.g. correcting a code review bot
suggestion that referenced `result.stdout`/`.stderr` when the real attrs
were `.output`/`.error`).

### Wording a reply to review findings

Draft the reply to a file, show Kyle the full text, and post only on an
explicit go-ahead ([[act-only-when-asked]]). In the draft:

- One bullet per finding, in the review's order, named by its title.
- Each bullet gives the decision (fixed in <sha>, dismissing, keeping it,
  leaving it), the reason, and whose position it follows: a human by
  `@username`, or "the review bot". A bare "agreed" or "dismissing" leaves
  the reader guessing who agreed with what.
- @-mention the human reviewer whose proposals the reply acts on, so they
  are notified. Do not @-mention the bot unless asking it for a re-review;
  a mention starts a pass.
- Write the bot's severity markers as words ("Red", "Yellow"), not its
  emoji: replies are ASCII-only ([[agent-attribution]]).

**Why:** on 2026-11-13 Kyle rejected "agreed, dismissing" as unclear about
who was agreed with and why, and asked for the human reviewer to be
@-mentioned; that reply also copied the bot's emoji markers.

### Posting a long reply

Post from the approved draft file, not a `-f body=...` shell string, so
backticks, quotes and newlines arrive exactly as approved. Pipe the JSON
body to `--input -` so no extra file is left behind ([[no-rm-workarounds]]);
the piped form was checked on 2026-11-25 against the stateless `markdown`
endpoint only. Like the PUT in section 4, the POST needs the content-type
header:
```
jq -n --rawfile b reply.md '{body: $b}' \
  | glab api -X POST -H 'Content-Type: application/json' --input - \
    "projects/PROJECT_ID/merge_requests/IID/discussions/DISCUSSION_ID/notes" > posted.json
jq -r .id posted.json   # link: .../merge_requests/IID#note_<id>
```
Diff `jq -r .body posted.json` against `reply.md` to confirm.

## 4. Update MR title/description (e.g. when scope changed)

Titles follow the subject rules in [[commit-message-format]] (no ticket key
in front). Short edits:
```
glab mr update IID --title "..." --description "$(cat body.md)"   # run from inside the repo, or pass -R group/sub/project
```
For a long description, round-trip it through a file to avoid shell
quoting. `glab api --input` sets no content type by itself, so without the
header the PUT fails with a bare `glab: HTTP 415`:
```
glab api "projects/PROJECT_ID/merge_requests/IID" | jq -r .description > desc.md   # then edit desc.md
jq -n --rawfile d desc.md '{description: $d}' \
  | glab api -X PUT -H 'Content-Type: application/json' --input - "projects/PROJECT_ID/merge_requests/IID"
```
Re-fetch afterwards and diff against `desc.md`.

## 5. Retrigger any code review bots for a re-review

If the code review appears to be automated, try @ mentioning the bot and
asking nicely for a re-review.

When replying to the bot's findings, post the re-review request as its own
reply after the response, so the bot reads the response first. For a full
re-review, put the request in the review's summary thread: a mention inside
one finding's thread may be answered for that finding only. Name the
commits that address the findings. Then wait for the verdict in the
background and report it to Kyle.

See also [site-specific instructions](~/.dotfiles/_sites/current/_ai/memories/code-review-bot.md).

## Notes
- Do not rely on the working directory carrying over between Bash tool
  calls: run `cd repo && git push` in ONE call, use `git -C repo`, or pass
  `-R group/sub/project` to glab.
- Review fixes: propose folding each into the commit it belongs to, or a
  follow-up commit, and confirm before force-pushing a branch under review;
  see [[git-history-rewrites]].
- On someone else's MR, ask Kyle whether to push or attach a `.patch` to a
  comment, and never rewrite the author's commits: see
  [[gitlab-mr-patch-comments]].
- glab is authed via `GITLAB_TOKEN` as Kyle George's user; where the token
  comes from is site-specific (see the site memories,
  ~/.dotfiles/_sites/current/_ai/AGENTS.md).
- For setting merge-order dependencies between MRs, see
  [[gitlab-mr-dependencies]].
