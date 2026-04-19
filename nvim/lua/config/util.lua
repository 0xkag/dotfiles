local M = {}

local uv = vim.uv or vim.loop
local root_markers = {
  ".git",
  "pyproject.toml",
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

function M.grep_prompt(opts)
  opts = opts or {}

  local cwd = opts.cwd or M.cwd()
  local title = opts.title or "Search"

  if vim.fn.executable("rg") == 1 then
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

    if vim.fn.executable("git") == 1 and M.is_git_repo(cwd) then
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

    if vim.fn.executable("grep") == 1 then
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
