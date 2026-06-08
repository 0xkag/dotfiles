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

## Sorting & Grouping

* DO group related things together.  For example, if you're generating code
  and it has classes and functions, the classes should usually be grouped
  together before the functions and classes should be sorted by name.
* DO sort everything that makes sense to sort.
* Things (e.g., variables, functions, etc.) should be sorted either
  lexicographically OR logically grouped (and then lexicographically sorted
  within the grouping).

## Comments

* DO NOT add meaningless end-of-line code comments.
* DO NOT add meaningless code comments above obvious single lines of code.
* DO add meaningful comments about blocks of code.

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
* DO maintain the plurality of variable names.  If something is signular, name
  it singularly.  If something is pulural, name it plurally.

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
  `topic: Phrase` subject, `--` body bullets, 75-col wrap, ASCII-only, refs +
  Co-Authored-By last

## GitLab mechanics

- [GitLab MR dependencies](~/.dotfiles/_ai/memories/gitlab-mr-dependencies.md) — set cross-project
  "blocked-by" via glab GraphQL (REST 400s); inline-array gotcha
- [glab MR review comments](~/.dotfiles/_ai/memories/glab-mr-review-comments.md) — find an MR,
  read/reply to inline + summary review comments, retrigger review bots

