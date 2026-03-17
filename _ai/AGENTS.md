# Conventions for AI

* Comments: DO NOT add meaningless end-of-line code comments.  DO NOT add
  meaningless code comments above obvious single lines of code.  DO add
  meaningful comments about blocks of code.

* Quoting: DO use single quotes (') for regular strings.  DO use triple quotes
  (""") for function and source unit docstrings, making sure that the starting
  """ and ending """ on lines by themselves.

* Whitespace: DO NOT add extra end-of-line whitespace.  DO NOT add two lines
  in between functions, that is a silly part of PEP8.  DO add single lines of
  whitespace between groups of logically related lines in functions in order
  to improve readability.

* Case: When generating SQL, DO NOT use UPPER CASE for SQL keywords.  SQL
  works just fine with lower case renderings of keywords, and that's much more
  pleasant to read.

* Naming: DO name variables and functions logically.  Generally speaking, if a
  bunch of functions or variables are directly related, prefix them all the
  same.  For example, if we're making functions that copy, list, and get
  widgets, name them as `widget_get()`, `widget_copy()`, and `widgets_list()`,
  NOT as `get_widgets()`, `copy_widgets()`, and `list_widgets()`.  DO maintain
  the plurality of variable names.  If something is signular, name it
  singularly.  If something is pulural, name it plurally.

* Sorting: Variables and functions should be sorted either lexicographically
  OR logically grouped (and then lexicographically sorted within the
  grouping).

* Imports: Imports must be grouped into the following sections, each separated
  by a single blank line: python standard library imports, third-party library
  imports, local company imports (imports provided by other packages at the
  company), and local project imports.  Within a group, sort the imports by
  the import name, regardless of if "import ..." or "from ... import" syntax
  is used.  When using "from ... import", using "from ... import (...)",
  putting each token after import on its own line, and putting the ending paren
  on its own line.
