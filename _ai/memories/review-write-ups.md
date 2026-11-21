---
name: review-write-ups
description: Review write-ups mark each finding's sources with bracketed
  tags ([run], [src], ...) and what needs Kyle's answer with [Kyle?]; a
  restatement reads fresh, with no references to earlier numbering
metadata:
  node_type: memory
  type: feedback
---

In review and audit write-ups:

- Mark where each finding's evidence came from with short bracketed tags,
  defined once in a legend at the top of the write-up. A tag names the
  source, not a confidence level, for example:
  - `[run]` reproduced by running something (a test build, a request)
  - `[src]` read in source code
  - `[prod]`, `[uat]` seen in that environment's live config or output
  - `[master]` read on a named branch of another repo
  - `[doc]` stated in external docs

  Pick tags that fit the review, keep them lower case, and put every tag
  that applies on the finding. Mark an inference as one in words (see
  [[evidence-over-inference]]).
- Tag any finding or question that needs Kyle's answer `[Kyle?]`, in the
  same bracket style and in the same legend. Never a bare `[Kyle]`.
- When Kyle asks for the findings restated, write them fresh, as if for a
  first-time reader: number the findings afresh, and drop old finding
  numbers, test IDs and back-references such as "as above" or "was #3".

**Why:** Kyle asked for `[Kyle?]` and fresh restatements while reviewing a
security write-up (2026-11-20): "Instead of `[Kyle]` denoting when I need
to answer something, say `[Kyle?]`. And there's no need to state the old
finding numbers. I want you to restate fresh like someone is reading it for
the first time." The same day he asked to keep the source tags too: "I
liked your `[<thing>]` style, where you used `[Kyle?]` for things I need to
respond to, but you also used `[<thing>]` to mark up your sources."

**How to apply:** start every review with the tag legend, tag findings from
the first draft, and use `[Kyle?]` for each open question; on a restatement
request, rewrite the whole report instead of patching the previous one with
cross-references.
