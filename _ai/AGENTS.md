# Conventions for AI Agents

These conventions are mostly for programming, but can apply generally too.

## General Style

* ALWAYS make edits that are consistent with the surrounding style in the
  source code unit file and/or the local project in terms of line length,
  variable and function naming, and other general formatting.  If a program's
  existing style conflicts with the guidelines here, prefer the existing style
  unless I specifically instruct you to ignore the local project conventions.
  Ask me to resolve any conflicts in your interpretation.
* Adapt my instructions here to the conventions of the programming language
  code being generated / edited.
* DO keep diffs as small as the change allows.  DO NOT split modules into
  packages, add registries or restructure working code unless it buys a
  real maintainability win, and say what the win is.
* DO NOT hardcode a home directory in scripts or config.  My home directory
  varies between hosts; use `$HOME` or `~` instead of hardcoding.  If a file
  doesn't respect $HOME, tell me so I can choose.

## Sorting & Grouping

* DO group related things together (semantic sorting).  For example, if you're
  generating code and it has classes and functions, the classes should usually
  be grouped together before the functions and classes should be sorted by
  name (lexicographic sorting).
* DO sort everything that makes sense to sort.
* Things (e.g., variables, functions, etc.) should be sorted either
  lexicographically OR semantically/logically grouped (and then
  lexicographically sorted within the grouping).
* Inside an existing section, place a new entry by plain lexicographic order
  among that section's entries.  The sections already carry the semantic
  grouping; DO NOT invent finer sub-groups to justify a different spot.

## Comments

* DO NOT add meaningless end-of-line code comments.
* DO NOT add meaningless code comments above obvious single lines of code.
* DO add meaningful comments about blocks of code.
* DO NOT write comments tagged `ponytail:` (or any other tool's marker),
  even when a skill or plugin asks for them.  Note a deliberate
  simplification or known limit in an ordinary comment in the surrounding
  style.

## Quoting

* In languages that support both double quotes and single quotes for strings
  (e.g., Python), DO use single quotes (') for regular strings (as long as
  that's in line with the General Style).
* In Python, DO use triple quotes (""") for function and source unit
  docstrings, making sure that the starting """ and ending """ on lines by
  themselves.

## Whitespace

* DO NOT add extra end-of-line whitespace.
* In Python, DO NOT add two lines in between functions, that is a silly part
  of PEP8.
* DO add single lines of whitespace between groups of logically related lines
  in functions in order to improve readability.

## Casing

* When generating SQL, DO NOT use UPPER CASE for SQL keywords.  SQL works just
  fine with lower case renderings of keywords, and that's much more pleasant
  to read.

## Naming

* DO name variables and functions and command line arguments etc. logically.
* Generally speaking, if a bunch of functions or variables are directly
  related, prefix them all the same.  For example, if we're making functions
  that copy, list, and get widgets, name them as `widget_get()`,
  `widget_copy()`, and `widgets_list()`, NOT as `get_widgets()`,
  `copy_widgets()`, and `list_widgets()`.
* DO maintain the plurality of variable names.  If something is singular, name
  it singularly.  If something is plural, name it plurally.

## Imports

* Imports should be grouped logically.
* Imports must be grouped into the following sections, each separated by a
  single blank line: standard library imports, third-party library imports,
  local company imports (imports provided by other packages at the company),
  and local project imports.  Within a group, sort the imports by the import
  name, regardless of if "import ..." or "from ... import" syntax is used.
  When using "from ... import", using "from ... import (...)", putting each
  token after import on its own line, and putting the ending paren on its own
  line.

## Commit message formatting

- [Commit message format](~/.dotfiles/_ai/memories/commit-message-format.md) — my required style:
  `topic: Phrase` subject (MR titles too), `--` body bullets, 75-col wrap with no line
  starting with `-`, ASCII-only, refs + Co-Authored-By last

## Communicating clearly

- DO NOT use ambiguous pronouns

  Example of what is ambiguous:

  ```
  The turbo encabulator and the widget are broken.  <more sentences> It needs
  to be fixed.
  ```

  Tell me what `it` is, or any other similar pronoun, unless it is blaringly
  obvious.  Even better than restating is just writing in a way that it is
  completely unambiguous.

- DO disambiguate things like MR references.  Instead of `!44`, say
  `turbo-encabulator!44`.

- DO highlight my decisions and calls to action in every reply, using both
  of the following, in this order:

  1. A line of the form `🔴 **ACTION NEEDED: <what I must do>.**` or
     `🔴 **DECISION: <the question>?**`.  For a decision, list the options
     as bullets under that line and mark the recommended one
     **(Recommended)**.
  2. For a decision, an `AskUserQuestion` call with the same question and
     options.  Put the recommended option first and add "(Recommended)" to
     its label.  Do this even when a sensible default exists, unless I have
     already told you the answer.

  Do not use strikethrough (`~~text~~`) or ANSI escape codes in replies;
  neither renders in my terminal.

## Working with me

- [Act only when asked](~/.dotfiles/_ai/memories/act-only-when-asked.md) — questions get answers,
  not edits; push, tag, MR changes and posting each need my explicit go-ahead
- [Agent attribution](~/.dotfiles/_ai/memories/agent-attribution.md) — Co-Authored-By on
  everything written on my behalf, ASCII-only, never the "Generated with" footer
- [Copy-pastable commands](~/.dotfiles/_ai/memories/copy-pastable-commands.md) - wrap
  commands for me to run at 78 columns with `\` continuations
- [Evidence over inference](~/.dotfiles/_ai/memories/evidence-over-inference.md) - cite
  sources, mark inferences, ask instead of guessing; take environment facts I
  state as given unless I tell you to verify (or you ask me and I say ok)
- [Never guess names](~/.dotfiles/_ai/memories/never-guess-names.md) — address people only by a
  name seen verbatim; call me Kyle

## Agent hygiene

- [Avoid scratchpad prefer
  cwd](~/.dotfiles/_ai/memories/avoid-scratchpad-prefer-cwd.md) - avoid using
  /tmp scratchpd and instead prefer the cwd; the scratch pad gets cleared if
  your sandbox (when running in a sandbox) restarts
- [No rm workarounds](~/.dotfiles/_ai/memories/no-rm-workarounds.md) — `rm` is denied; never
  delete another way, avoid intermediates, ask me to remove files

## Git workflow

- [Branch & worktree creation](~/.dotfiles/_ai/memories/git-branch-creation.md) — never create a
  branch or worktree unless I ask; suggest one freely, then wait for a yes
- [Branch naming](~/.dotfiles/_ai/memories/git-branch-naming.md) — plain descriptive kebab-case
  slug, no `feature/` / `bugfix/` / `chore/` prefix
- [History rewrites](~/.dotfiles/_ai/memories/git-history-rewrites.md) — one complete change per
  commit, fold fix-ups in, bump last; old sha, byte-for-byte check, `--force-with-lease`

## GitLab mechanics

- [GitLab MR dependencies](~/.dotfiles/_ai/memories/gitlab-mr-dependencies.md) — set cross-project
  "blocked-by" via REST blocks (global MR id) or GraphQL; inline-array gotcha
- [GitLab MR patch comments](~/.dotfiles/_ai/memories/gitlab-mr-patch-comments.md) — on others'
  MRs, ask me whether to push or comment with a .patch; patch steps + Slack @ mention request
- [glab MR review comments](~/.dotfiles/_ai/memories/glab-mr-review-comments.md) — find an MR,
  read/reply to inline + summary review comments (check `resolved` first), retrigger review bots

## Site-specific

Site-specific memories go in `~/.dotfiles/_sites/current/_ai/memories/`, never in
`~/.dotfiles/_ai/memories/`, which is public and for global use.  The current site's index
(auth, internal hosts, proxies, tooling and vocabulary) is imported here when it exists:

@~/.dotfiles/_sites/current/_ai/AGENTS.md
