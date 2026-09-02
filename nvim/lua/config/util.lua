local M = {}

local uv = vim.uv or vim.loop
local tools = require("config.tools")
local root_markers = {
  ".git",
  ".python-version",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "package.json",
  "tsconfig.json",
  "Cargo.toml",
  "go.mod",
  "Makefile",
  "ansible.cfg",
  ".terraform",
}
local listchars_profiles = {
  unicode = {
    eol = "¶",
    extends = ">",
    nbsp = "_",
    precedes = "<",
    tab = "»·",
  },
  ascii = {
    eol = "$",
    extends = ">",
    nbsp = "_",
    precedes = "<",
    tab = ">-",
  },
}

local function to_absolute(path, cwd)
  if path:sub(1, 1) == "/" then
    return path
  end
  return vim.fs.joinpath(cwd, path)
end

function M.cwd()
  return uv.cwd()
end

function M.find_root(path)
  if not path or path == "" then
    return nil
  end

  return vim.fs.root(path, root_markers)
end

function M.project_root(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return M.cwd()
  end
  return M.find_root(name) or M.cwd()
end

-- Whether `path` is inside a git worktree, nested project roots included: a
-- `.git` next to it is only the toplevel case.
function M.is_git_repo(path)
  return require("config.gitdiff").repo_toplevel(path, true) ~= nil
end

local git_status_width = 2

-- Prefix telescope's file entries with a one-character git status mark, so the
-- file picker shows what changed against the active diff base without becoming
-- a separate picker. Wrapping the built-in file entry maker is what keeps
-- devicons and path highlighting; the highlight ranges it returns are shifted
-- right by the width of the column added in front of them.
local function gen_from_file_with_status(opts, marks_of)
  local entry_maker = require("telescope.make_entry").gen_from_file(opts)

  return function(line)
    local entry = entry_maker(line)
    if not entry then
      return entry
    end

    local display = entry.display
    entry.display = function(e, picker)
      local text, style = display(e, picker)
      local mark = marks_of()[to_absolute(e.value, opts.cwd or M.cwd())] or ""

      local shifted = {}
      for i, item in ipairs(style or {}) do
        shifted[i] = { { item[1][1] + git_status_width, item[1][2] + git_status_width }, item[2] }
      end
      if mark ~= "" then
        table.insert(shifted, 1, { { 0, #mark }, require("config.gitdiff").status_highlight(mark) })
      end

      return string.format("%-" .. git_status_width .. "s", mark) .. text, shifted
    end
    return entry
  end
end

-- Redraw an open picker's entries in place: telescope re-runs the finder over
-- the current prompt, which is what makes the entry maker render again.
local function refresh_picker(prompt_bufnr)
  if not prompt_bufnr or not vim.api.nvim_buf_is_valid(prompt_bufnr) then
    return
  end
  local ok, picker = pcall(function()
    return require("telescope.actions.state").get_current_picker(prompt_bufnr)
  end)
  if ok and picker then
    picker:refresh()
  end
end

function M.find_files(opts)
  opts = opts or {}

  local builtin = require("telescope.builtin")
  local cwd = opts.cwd or M.cwd()

  -- git ls-files cannot combine --others with --recurse-submodules, and
  -- telescope rejects the pair outright rather than dropping one, so keep
  -- untracked: a file just created is exactly the one you want to find,
  -- while recursing submodules buries the project under vendored trees
  -- (~60 of them under _lib in ~/.dotfiles, turning 373 paths into 22k).
  if opts.git ~= false and M.is_git_repo(cwd) then
    local gitdiff = require("config.gitdiff")
    local git_opts = {
      cwd = cwd,
      prompt_title = (opts.title or "Git Files") .. " (vs " .. gitdiff.label() .. ")",
      show_untracked = true,
    }

    -- The marks come from a listing that may still be running: the picker
    -- opens at once with whatever is cached and is redrawn when the listing
    -- lands. Its prompt buffer is known once it is open, which is before any
    -- landing can be delivered.
    local marks, prompt_bufnr = {}, nil
    local function fetch_marks()
      marks = gitdiff.status_by_path(cwd, {
        on_update = function()
          fetch_marks()
          refresh_picker(prompt_bufnr)
        end,
      })
    end
    fetch_marks()
    git_opts.entry_maker = gen_from_file_with_status(git_opts, function()
      return marks
    end)
    builtin.git_files(git_opts)
    prompt_bufnr = vim.api.nvim_get_current_buf()
    return
  end

  builtin.find_files({
    cwd = cwd,
    hidden = true,
    no_ignore = opts.no_ignore or false,
    prompt_title = opts.title or "Find Files",
  })
end

function M.project_files()
  M.find_files({
    cwd = M.project_root(0),
    title = "Project Files",
  })
end

function M.dotfiles()
  M.find_files({
    cwd = vim.fs.joinpath(vim.env.HOME, ".dotfiles"),
    title = "Dotfiles",
  })
end

function M.listchars_profile(name)
  local profile = listchars_profiles[name]
  if not profile then
    vim.notify("Unknown listchars profile: " .. tostring(name), vim.log.levels.WARN)
    return
  end

  vim.opt.listchars = vim.tbl_extend("force", {}, profile)
end

function M.listchars_unicode()
  M.listchars_profile("unicode")
end

function M.listchars_ascii()
  M.listchars_profile("ascii")
end

-- The live visual selection as 1-based rows and 0-based columns (the mark
-- convention), start before end, plus the visual mode letter. nil outside
-- visual mode.
--
-- Read getpos("v") / getpos(".") rather than the '< '> marks: an x-mode Lua
-- mapping fires while still in visual mode, and the marks are only updated on
-- leaving it, so a mark-based reading acts on the previous selection.
function M.visual_range()
  local mode = vim.fn.mode()
  if not mode:match("^[vV\22sS\19]") then
    return nil
  end

  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local start_row, start_col, end_row, end_col = anchor[2], anchor[3] - 1, cursor[2], cursor[3] - 1
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  return {
    end_col = end_col,
    end_row = end_row,
    mode = mode,
    start_col = start_col,
    start_row = start_row,
  }
end

function M.visual_selection_text()
  local range = M.visual_range()
  if not range then
    return nil
  end

  local lines
  if range.mode == "V" or range.mode == "S" then
    lines = vim.api.nvim_buf_get_lines(0, range.start_row - 1, range.end_row, false)
  else
    local last = vim.api.nvim_buf_get_lines(0, range.end_row - 1, range.end_row, false)[1] or ""
    local end_col = math.min(range.end_col + 1, #last)
    lines = vim.api.nvim_buf_get_text(0, range.start_row - 1, range.start_col, range.end_row - 1, end_col, {})
  end

  if not lines or #lines == 0 then
    return nil
  end

  return table.concat(lines, "\n")
end

local function literal_pattern(text)
  local pattern = "\\V" .. vim.fn.escape(text, [[/\]])
  return pattern:gsub("\n", [[\n]])
end
M.literal_pattern = literal_pattern

function M.search_visual(forward)
  local text = M.visual_selection_text()
  if not text or text == "" then
    return
  end

  local pattern = literal_pattern(text)
  vim.fn.setreg("/", pattern)
  vim.opt.hlsearch = true
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. (forward and "n" or "N")), "n", false)
end

function M.substitute_visual()
  local text = M.visual_selection_text()
  if not text or text == "" then
    return
  end

  local command = ":%s/" .. literal_pattern(text) .. "//gc"
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. command .. string.rep("<Left>", 3)), "n", false)
end

local function set_quickfix(title, items)
  vim.fn.setqflist({}, " ", {
    title = title,
    items = items,
  })
  vim.cmd.copen()
end

local function run_search(command, cwd, title, parser)
  vim.system(command, { cwd = cwd, text = true }, function(result)
    local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
    local items = {}

    for _, line in ipairs(lines) do
      local item = parser(line, cwd)
      if item then
        table.insert(items, item)
      end
    end

    vim.schedule(function()
      if #items == 0 then
        vim.notify("No matches found for " .. title, vim.log.levels.INFO)
        return
      end
      set_quickfix(title, items)
    end)
  end)
end

-- Exposed on M (underscore prefix) for headless specs; callers use the locals.
local function parse_git_grep(line, cwd)
  local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
  if not file then
    return nil
  end
  return {
    filename = to_absolute(file, cwd),
    lnum = tonumber(lnum),
    col = tonumber(col),
    text = text,
  }
end

local function parse_grep(line)
  local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
  if not file then
    return nil
  end
  return {
    filename = file,
    lnum = tonumber(lnum),
    text = text,
  }
end

local function parse_global(line, cwd)
  local item = parse_grep(line)
  if not item then
    return nil
  end

  if cwd then
    item.filename = to_absolute(item.filename, cwd)
  end

  return item
end

M._parse_git_grep = parse_git_grep
M._parse_grep = parse_grep
M._parse_global = parse_global
M._to_absolute = to_absolute

function M.grep_prompt(opts)
  opts = opts or {}

  local cwd = opts.cwd or M.cwd()
  local title = opts.title or "Search"

  if tools.available("rg") then
    require("telescope.builtin").live_grep({
      cwd = cwd,
      prompt_title = title,
    })
    return
  end

  vim.ui.input({ prompt = title .. " > " }, function(input)
    if not input or input == "" then
      return
    end

    if tools.available("git") and M.is_git_repo(cwd) then
      run_search({
        "git",
        "grep",
        "-nI",
        "--column",
        "--no-color",
        "-e",
        input,
      }, cwd, title .. ": " .. input, parse_git_grep)
      return
    end

    if tools.available("grep") then
      run_search({
        "grep",
        "-RIn",
        "--exclude-dir=.git",
        "--exclude-dir=node_modules",
        "--exclude-dir=.mypy_cache",
        "--exclude-dir=.pytest_cache",
        "--",
        input,
        cwd,
      }, nil, title .. ": " .. input, parse_grep)
      return
    end

    vim.notify("Install ripgrep or grep to use project search.", vim.log.levels.WARN)
  end)
end

function M.cwd_grep()
  M.grep_prompt({
    cwd = M.cwd(),
    title = "Search CWD",
  })
end

function M.project_grep()
  M.grep_prompt({
    cwd = M.project_root(0),
    title = "Project Grep",
  })
end

function M.global_root(bufnr)
  if not tools.available("global") then
    return nil
  end

  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  local start_dir = name ~= "" and vim.fs.dirname(name) or M.project_root(bufnr)
  local result = vim.system({ "global", "--print", "root" }, {
    cwd = start_dir,
    text = true,
  }):wait()

  if result.code ~= 0 then
    return nil
  end

  local root = vim.trim(result.stdout or "")
  if root == "" then
    return nil
  end

  return root
end

local function global_items(root, mode, symbol)
  local command = { "global", "--result=grep" }

  if mode == "definition" then
    table.insert(command, "-d")
  elseif mode == "reference" then
    table.insert(command, "-r")
  elseif mode == "symbol" then
    table.insert(command, "-s")
  end

  table.insert(command, symbol)

  local result = vim.system(command, {
    cwd = root,
    text = true,
  }):wait()

  local items = {}
  for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
    local item = parse_global(line, root)
    if item then
      table.insert(items, item)
    end
  end

  return items
end

local function jump_to_item(item)
  vim.cmd.edit(vim.fn.fnameescape(item.filename))
  vim.api.nvim_win_set_cursor(0, {
    item.lnum,
    math.max((item.col or 1) - 1, 0),
  })
end

local function show_global_items(title, items)
  if #items == 0 then
    vim.notify("No matches found for " .. title, vim.log.levels.INFO)
    return
  end

  if #items == 1 then
    jump_to_item(items[1])
    return
  end

  set_quickfix(title, items)
end

function M.global_definitions(symbol)
  local root = M.global_root(0)
  if not root then
    vim.notify("GNU Global database not found for this project.", vim.log.levels.INFO)
    return
  end

  symbol = symbol or vim.fn.expand("<cword>")
  if symbol == "" then
    return
  end

  local items = global_items(root, "definition", symbol)
  if #items == 0 then
    items = global_items(root, "symbol", symbol)
  end

  show_global_items("Global definitions: " .. symbol, items)
end

function M.global_references(symbol)
  local root = M.global_root(0)
  if not root then
    vim.notify("GNU Global database not found for this project.", vim.log.levels.INFO)
    return
  end

  symbol = symbol or vim.fn.expand("<cword>")
  if symbol == "" then
    return
  end

  show_global_items("Global references: " .. symbol, global_items(root, "reference", symbol))
end

function M.global_symbols(symbol)
  local root = M.global_root(0)
  if not root then
    vim.notify("GNU Global database not found for this project.", vim.log.levels.INFO)
    return
  end

  symbol = symbol or vim.fn.expand("<cword>")
  if symbol == "" then
    return
  end

  show_global_items("Global symbols: " .. symbol, global_items(root, "symbol", symbol))
end

function M.global_prompt()
  vim.ui.input({
    prompt = "Global symbol > ",
    default = vim.fn.expand("<cword>"),
  }, function(input)
    if not input or input == "" then
      return
    end

    M.global_symbols(input)
  end)
end

function M.global_update()
  local root = M.global_root(0)
  if not root then
    vim.notify("GNU Global database not found for this project.", vim.log.levels.INFO)
    return
  end

  vim.system({ "global", "-u" }, {
    cwd = root,
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("Updated GNU Global tags.", vim.log.levels.INFO)
      else
        vim.notify("Failed to update GNU Global tags.", vim.log.levels.ERROR)
      end
    end)
  end)
end

local function squeeze_line(line)
  if line:match("^%s*$") then
    return ""
  end
  local indent, body = line:match("^(%s*)(.-)%s*$")
  return indent .. body:gsub("%s+", " ")
end
M._squeeze_line = squeeze_line

function M.squeeze_spaces(start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  for index, line in ipairs(lines) do
    lines[index] = squeeze_line(line)
  end
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end

function M.squeeze_spaces_line()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  M.squeeze_spaces(line, line)
end

function M.squeeze_spaces_visual()
  local range = M.visual_range()
  if range then
    M.squeeze_spaces(range.start_row, range.end_row)
  end
end

return M
