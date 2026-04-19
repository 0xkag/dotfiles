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

local function to_absolute(path, cwd)
  if path:sub(1, 1) == "/" then
    return path
  end
  return vim.fs.joinpath(cwd, path)
end

function M.cwd()
  return uv.cwd()
end

function M.project_root(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return M.cwd()
  end
  return vim.fs.root(name, root_markers) or M.cwd()
end

function M.is_git_repo(path)
  return vim.fn.isdirectory(vim.fs.joinpath(path, ".git")) == 1 or vim.fn.filereadable(vim.fs.joinpath(path, ".git")) == 1
end

function M.find_files(opts)
  opts = opts or {}

  local builtin = require("telescope.builtin")
  local cwd = opts.cwd or M.cwd()

  if opts.git ~= false and M.is_git_repo(cwd) then
    builtin.git_files({
      cwd = cwd,
      prompt_title = opts.title or "Git Files",
      recurse_submodules = true,
      show_untracked = true,
    })
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

local function normalize_range(start_pos, end_pos)
  if start_pos[1] > end_pos[1] or (start_pos[1] == end_pos[1] and start_pos[2] > end_pos[2]) then
    return end_pos, start_pos
  end

  return start_pos, end_pos
end

function M.visual_selection_text()
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")
  if start_pos[1] == 0 or end_pos[1] == 0 then
    return nil
  end

  start_pos, end_pos = normalize_range(start_pos, end_pos)

  local mode = vim.fn.visualmode()
  local lines

  if mode == "V" then
    lines = vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, end_pos[1], false)
  else
    lines = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2], end_pos[1] - 1, end_pos[2] + 1, {})
  end

  if not lines or #lines == 0 then
    return nil
  end

  return table.concat(lines, "\n")
end

function M.search_visual(forward)
  local text = M.visual_selection_text()
  if not text or text == "" then
    return
  end

  local pattern = "\\V" .. vim.fn.escape(text, [[\]])
  pattern = pattern:gsub("\n", [[\n]])
  vim.fn.setreg("/", pattern)
  vim.opt.hlsearch = true
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. (forward and "n" or "N")), "n", false)
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
  M.squeeze_spaces(vim.fn.line("'<"), vim.fn.line("'>"))
end

return M
