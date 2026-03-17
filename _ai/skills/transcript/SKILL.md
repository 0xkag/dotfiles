---
name: transcript
description: Use when the user asks to write a transcript, record, or summary of the current conversation as a markdown file. Also use when asked to document a design discussion, capture a conversation for sharing, or create a readable log of the session.
---

# Conversation Transcript

Write a clean, readable markdown transcript of the current conversation, capturing only the human-facing dialog -- what the user said and what you said back.

## What to Include

- **User messages**: Their questions, instructions, decisions, and context they provided. Reproduce substantively (not verbatim system-injected metadata).
- **Your responses**: The explanations, questions, proposals, and summaries you gave back to the user.
- **Structured questions and answers**: When you asked the user a question with multiple-choice options (via AskUserQuestion), reproduce the **full question text**, **every option with its label and description**, and the **user's selected answer** (including any notes they added). Do NOT summarize these as "I asked about X" — show the actual question and choices.
- **Design presentations**: When you presented design proposals, architecture descriptions, CLI interface specs, output format examples, or approach trade-offs as part of the conversation, reproduce them **faithfully and in full** — not as a brief summary. These are key decision points that the transcript must capture.
- **Produced artifacts (full content)**: Plans, designs, specs, or other structured documents you created during the conversation. Embed the **complete final version** in `<details>` blocks (see below). Do NOT abbreviate or summarize plan content — include it verbatim. If a plan went through iterations, include only the final approved version and note earlier versions were revised based on feedback.
- **Outcome summaries**: Brief description of implementation work, test results, commits.

## What to Exclude

- Tool calls and tool output (file reads, grep results, bash output)
- System prompts and system reminders
- Internal exploration notes ("Let me read the file...", "Let me check...")
- Skill invocations and skill content
- Agent dispatches and agent results

## Formatting Rules

### Headings for speakers

Use `## User` and `## Claude` to alternate between speakers. For long conversations, combine consecutive exchanges naturally rather than creating dozens of tiny sections.

### Elided actions

When you performed non-conversational work (reading files, running tests, implementing code), summarize it in italics. **Always specify which tools or APIs were used and what was discovered** — not just "explored the codebase" but the concrete findings:

```markdown
*(Explored the kubernetes-config repo using Grep and Glob — found 163K YAML files across 48 clusters, 2,728 unique images from multiple registries. No existing scanning scripts.)*
```

```markdown
*(Used boto3 describe_repositories to enumerate ECR repos. Found 42 core-infra/* repositories containing 23,169 images published after 2024-10-01.)*
```

### Embedded artifacts

When you produced a substantial document during the conversation (a plan, spec, design doc), embed it in a collapsible `<details>` block to keep it visually distinct from the dialog:

```markdown
## Claude

*(Produced the following implementation plan.)*

<details>
<summary>Implementation Plan: Feature Name (click to expand)</summary>

... full plan content with markdown formatting preserved ...

</details>
```

This preserves the artifact's internal markdown (tables, code blocks, headers) while keeping the conversation flow readable.

### Questions with structured options

When you asked the user a structured question with multiple-choice options, format it as a blockquote with a bulleted option list, followed by the user's answer:

```markdown
## Claude

> **Scope:** Are you only concerned with images from the primary ECR registry, or do you also need to check third-party/public images?
>
> - **ECR only (674283286888)** — Only check images hosted in the primary Arcesium ECR. Public/third-party images are out of scope.
> - **All registries** — Check every image regardless of registry origin.
> - **ECR + registry.arcesium.com** — Check both Arcesium-controlled registries but skip public images.

## User

ECR only (674283286888).
```

If the user added notes beyond their selection, include those too.

### Implementation summaries

When you implemented something, use a numbered list of what was done followed by the verification result:

```markdown
*(Implemented the plan:)*

1. Added X to file Y
2. Modified Z to support W
3. Added tests for A, B, C

**Verification**: `Ran 460 tests in 2.8s -- OK` (0 failures)
```

## Output

Write to a markdown file in the current working directory. Name it descriptively based on the conversation topic (e.g., `conversation-arc-in-milter.md`, `transcript-auth-refactor.md`). Ask the user for the filename if the topic isn't obvious.
