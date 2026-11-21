---
name: evidence-over-inference
description: Back claims with a source, mark inferences, ask instead of
  guessing; but take facts Kyle states about the environment as given
metadata:
  node_type: memory
  type: feedback
---

Kyle knows the environments deeply and expects claims backed by evidence.

- Say where each claim comes from: a file and line, command output, a doc
  URL. Mark anything else as an inference.
- When something cannot be determined from what is in reach, ask in a short
  numbered list instead of filling the gap. Kyle prefers being asked.
- Re-verify earlier analysis (another agent's doc, a remembered fact)
  against the current source before repeating it; rebases and later commits
  leave line references and constants stale.
- In reviews, separate findings into verified against the code, verified
  against external docs, and needs Kyle (data out of reach), tagged
  `[Kyle?]` per [[review-write-ups]].

**But take facts Kyle states about the environment as given.** "These roles
are available" means build on it: no mock harnesses, credential probes or
multi-repo archaeology to prove it. A syntax check or the code's own
self-test is fine. If a stated fact seems to conflict with evidence, say so
in one line and carry on with Kyle's version.

**Why:** "Do not hesitate to ask me for clarification / confirmation. Do
not guess." (2026-10-21, after an earlier agent's analysis had gone stale
across a rebase); "where do you see that?" (2026-11-03, after an agent
asserted a wrong fact about an ingress); and "You don't need to self-test.
I am telling you that these roles are available. Proceed under that
assumption." (2026-10-21, after two turns spent on a mock harness).

**How to apply:** before stating a fact about Kyle's systems, have the
source in hand or label it an inference; when Kyle supplies the fact,
proceed on it.
