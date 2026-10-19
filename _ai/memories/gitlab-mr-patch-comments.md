---
name: gitlab-mr-patch-comments
description: "On someone else's GitLab MR, ask Kyle whether to push fixes or
post them as a .patch in an MR comment; how to do the patch comment"
metadata:
  node_type: memory
  type: feedback
---

Fixes to someone else's MR go out one of two ways: pushed to the author's
branch, or attached as a `.patch` to an MR comment for the author to apply.

## Push or patch? Ask

Kyle usually says which one up front ("push the branch" or "do not push;
attach a .patch"). If not, ask before doing either; never push to another
author's branch on a guess. Local commits are fine either way.

- **Push:** follow [[glab-mr-review-comments]].
- **Patch:** follow the workflow below. Also ask whether the author should
  apply it with `--reset-author` or keep Kyle as the author, unless Kyle
  already said.

## Patch comment workflow

1. Commit the fixes locally on top of the MR head; note that base sha.
2. Write the patch into the worktree and leave it untracked:
   `git format-patch --stdout <base>..HEAD > mr-<iid>-review.patch`
3. Check that it applies to the base and reproduces your tree, without
   touching the checkout:
   ```
   export GIT_INDEX_FILE=<scratchpad>/am-check.idx
   git read-tree <base> && git apply --cached mr-<iid>-review.patch &&
     [ "$(git write-tree)" = "$(git rev-parse 'HEAD^{tree}')" ] && echo patch-ok
   unset GIT_INDEX_FILE
   ```
4. Upload it to the project and use the returned markdown link; see
   [[glab-token-source]] for `GITLAB_TOKEN`:
   ```
   curl -sS --fail --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
     --form "file=@mr-<iid>-review.patch" \
     https://gitlab.com/api/v4/projects/<project-id>/uploads | jq -r .markdown
   ```
   If the patch changes afterwards (even only a commit message), upload it
   again and link the new upload; the old link keeps serving the stale file.
5. Post a top-level comment, unless told to reply in a thread: @ mention the
   author, say the changes are NOT pushed, give the patch link and base sha,
   explain what each commit changes and why, and show how to apply it:
   ```
   git checkout <branch>   # at <base>
   git am mr-<iid>-review.patch
   git push
   ```
   The comment always tells the author whether to apply the patch with
   `--reset-author`, making themselves the author, or not, keeping Kyle as
   the author (plain `git am` does that). When the author should reset it,
   the comment gives the steps in a code block, with the rebase before the
   push:
   ```
   git checkout <branch>   # at <base>
   git am mr-<iid>-review.patch
   git rebase --exec 'git commit --amend --no-edit --reset-author' HEAD~<n>
   git push
   ```
   Don't edit the MR title or description; when they need changing, put the
   proposed text in a collapsible `<details>` block in the comment.
6. Reply in-thread to that comment, asking the author to @ mention Kyle in
   Slack, in the appropriate channel or thread, once they've applied it and
   the MR is ready again. Don't spell out Kyle's username; they know it:
   `@<author> once you've applied it, please @ mention me in Slack.`
7. Every comment ends with the Co-Authored-By line; see
   [[glab-mr-review-comments]].

**Why:** pushing changes a branch someone else owns, so it is Kyle's call; a
patch lets the author apply the changes themselves and keep their branch and
review history, and the Slack mention is how Kyle learns the MR is ready for
another look.

**How to apply:** for any fix to an MR Kyle doesn't own, check whether Kyle
said push or patch; if not, ask. For a patch, follow the steps above and keep
the local `.patch` copy so it can be re-uploaded.
