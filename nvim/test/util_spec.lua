-- Headless test harness for config.util pure logic.
-- Run: nvim --headless -u NONE -l nvim/test/util_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/util_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

local util = require("config.util")

-- literal_pattern(): builds a \V (very-nomagic) search pattern, escaping the
-- search separator and backslash, and turning real newlines into \n atoms.
do
  check("literal_pattern prefixes \\V", util.literal_pattern("abc") == [[\Vabc]], util.literal_pattern("abc"))
  check("literal_pattern escapes slash", util.literal_pattern("a/b") == [[\Va\/b]], util.literal_pattern("a/b"))
  check("literal_pattern escapes backslash", util.literal_pattern([[a\b]]) == [[\Va\\b]], util.literal_pattern([[a\b]]))
  check(
    "literal_pattern turns newline into \\n",
    util.literal_pattern("a\nb") == [[\Va\nb]],
    util.literal_pattern("a\nb")
  )
end

-- _to_absolute(): leaves absolute paths untouched, joins relative onto cwd.
do
  check("to_absolute keeps absolute", util._to_absolute("/x/y", "/cwd") == "/x/y", util._to_absolute("/x/y", "/cwd"))
  check(
    "to_absolute joins relative",
    util._to_absolute("a/b.lua", "/proj") == "/proj/a/b.lua",
    util._to_absolute("a/b.lua", "/proj")
  )
end

-- _parse_git_grep(): "file:lnum:col:text" with column, filename made absolute.
do
  local item = util._parse_git_grep("src/a.lua:12:4:local x = 1", "/proj")
  check("git_grep filename absolute", item and item.filename == "/proj/src/a.lua", item and item.filename)
  check("git_grep lnum", item and item.lnum == 12, item and item.lnum)
  check("git_grep col", item and item.col == 4, item and item.col)
  check("git_grep text", item and item.text == "local x = 1", item and item.text)
  -- A colon in the matched text must not be mis-split (lnum/col are numeric).
  local colon = util._parse_git_grep("a.lua:3:1:foo: bar", "/p")
  check("git_grep keeps colon in text", colon and colon.text == "foo: bar", colon and colon.text)
  check("git_grep rejects non-match", util._parse_git_grep("no colons here", "/p") == nil)
end

-- _parse_grep(): "file:lnum:text" (no column), filename left as-is.
do
  local item = util._parse_grep("src/a.lua:7:hit")
  check("grep filename verbatim", item and item.filename == "src/a.lua", item and item.filename)
  check("grep lnum", item and item.lnum == 7, item and item.lnum)
  check("grep text", item and item.text == "hit", item and item.text)
  check("grep has no col", item and item.col == nil, item and item.col)
  check("grep rejects non-match", util._parse_grep("nope") == nil)
end

-- _parse_global(): like grep, but resolves the filename against the root.
do
  local item = util._parse_global("a/b.c:9:def foo", "/root")
  check("global filename absolute", item and item.filename == "/root/a/b.c", item and item.filename)
  check("global lnum", item and item.lnum == 9, item and item.lnum)
  check("global rejects non-match", util._parse_global("bad", "/root") == nil)
end

-- _squeeze_line(): collapse interior whitespace runs to one space, preserve
-- leading indent, and reduce all-blank lines to empty.
do
  check("squeeze blank -> empty", util._squeeze_line("   ") == "", util._squeeze_line("   "))
  check("squeeze collapses interior", util._squeeze_line("a   b\tc") == "a b c", util._squeeze_line("a   b\tc"))
  check("squeeze preserves indent", util._squeeze_line("    a  b") == "    a b", util._squeeze_line("    a  b"))
  check("squeeze trims trailing", util._squeeze_line("a b   ") == "a b", util._squeeze_line("a b   "))
end

-- find_root() / project_root(): root marker walk and cwd fallback.
do
  check("find_root nil for empty", util.find_root("") == nil)
  check("find_root nil for nil", util.find_root(nil) == nil)
  -- This repo's nvim/ tree sits under a .git checkout, so a real path resolves.
  local root = util.find_root(here .. "/lua/config/util.lua")
  check("find_root finds a marker dir", type(root) == "string" and #root > 0, root)
  -- An unnamed buffer (no file) falls back to cwd.
  check("project_root falls back to cwd", util.project_root(0) == util.cwd(), util.project_root(0))
end

-- visual_selection_text(): linewise (V) joins whole lines; charwise pulls the
-- exact span. Drive it through real buffer marks.
do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world", "second line", "third" })
  -- Linewise selection of lines 1..2 via the '< '> marks + visualmode V.
  vim.api.nvim_buf_set_mark(0, "<", 1, 0, {})
  vim.api.nvim_buf_set_mark(0, ">", 2, 0, {})
  vim.fn.setreg("/", "") -- unrelated, keep state clean
  -- Force visualmode() to report 'V' by entering and leaving linewise visual.
  vim.cmd("normal! 1GVj\27")
  local linewise = util.visual_selection_text()
  check("visual linewise joins lines", linewise == "hello world\nsecond line", linewise)

  -- Charwise selection: columns 0..4 on line 1 ("hello").
  vim.cmd("normal! 1G0v4l\27")
  local charwise = util.visual_selection_text()
  check("visual charwise span", charwise == "hello", charwise)
end

-- find_files(): picks git_files inside a repo and find_files outside one, and
-- must never ask git_files for both --others and --recurse-submodules, which
-- telescope refuses outright (the picker then never opens). Inside a repo it
-- also decorates entries with a git status mark from the active diff base.
do
  local calls = {}
  package.preload["telescope.builtin"] = function()
    return {
      find_files = function(opts)
        table.insert(calls, { picker = "find_files", opts = opts })
      end,
      git_files = function(opts)
        table.insert(calls, { picker = "git_files", opts = opts })
      end,
    }
  end

  -- Stand in for telescope's file entry maker: one icon-width highlight so the
  -- shifting the status column has to do is observable.
  package.preload["telescope.make_entry"] = function()
    return {
      gen_from_file = function(_)
        return function(line)
          return {
            display = function(e)
              return "IC " .. e.value, { { { 0, 3 }, "DevIcon" } }
            end,
            ordinal = line,
            value = line,
          }
        end
      end,
    }
  end

  -- A real repo: the marks come from git, not from a fixture.
  local repo = vim.fn.tempname()
  vim.fn.mkdir(repo, "p")
  local function git(args)
    local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", repo }, args))
    assert(vim.v.shell_error == 0, table.concat(out, "\n"))
    return out
  end
  vim.fn.writefile({ "one" }, repo .. "/tracked")
  vim.fn.writefile({ "keep" }, repo .. "/untouched")
  git({ "init", "-q", "-b", "master" })
  git({ "config", "user.email", "t@t" })
  git({ "config", "user.name", "t" })
  git({ "add", "-A" })
  git({ "commit", "-q", "-m", "A" })
  vim.fn.writefile({ "changed" }, repo .. "/tracked")
  vim.fn.writefile({ "fresh" }, repo .. "/untracked")

  util.find_files({ cwd = repo, title = "Project Files" })
  local picker = calls[1]
  check("find_files uses git_files in a repo", picker and picker.picker == "git_files", picker and picker.picker)
  check("git_files keeps untracked files", picker and picker.opts.show_untracked == true, picker and picker.opts.show_untracked)
  check(
    "git_files does not also recurse submodules",
    picker and picker.opts.recurse_submodules == nil,
    picker and picker.opts.recurse_submodules
  )
  check(
    "the title names the active base",
    picker and picker.opts.prompt_title == "Project Files (vs index)",
    picker and picker.opts.prompt_title
  )

  -- Render an entry the way telescope's entry_display.resolve does.
  local function shown(path)
    local entry = picker.opts.entry_maker(path)
    local text, style = entry.display(entry)
    return text, style
  end

  local modified, modified_style = shown("tracked")
  check("a modified file is marked", modified == "M IC tracked", modified)
  check("the mark is highlighted as a change", modified_style[1][2] == "TelescopeResultsDiffChange", modified_style[1][2])
  check("the mark covers only itself", modified_style[1][1][2] == 1, vim.inspect(modified_style[1][1]))
  check(
    "the wrapped highlight shifts by the column width",
    modified_style[2][1][1] == 2 and modified_style[2][1][2] == 5,
    vim.inspect(modified_style[2][1])
  )

  local untracked, untracked_style = shown("untracked")
  check("an untracked file is marked", untracked == "? IC untracked", untracked)
  check(
    "untracked gets its own highlight",
    untracked_style[1][2] == "TelescopeResultsDiffUntracked",
    untracked_style[1][2]
  )

  local clean, clean_style = shown("untouched")
  check("an unchanged file gets a blank column", clean == "  IC untouched", clean)
  check("an unchanged file adds no highlight", #clean_style == 1, #clean_style)

  local plain = vim.fn.tempname()
  vim.fn.mkdir(plain, "p")
  util.find_files({ cwd = plain })
  check("find_files falls back outside a repo", calls[2] and calls[2].picker == "find_files", calls[2] and calls[2].picker)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
