-- The external tools this config leans on, one table of features, reported two
-- ways: a once-per-session warning on the first buffer of a filetype (the
-- autocmd at the end, or <leader>cm on demand), and `:checkhealth config`
-- (config/health.lua), which reads M.report(). The health report replaced a
-- startup sweep that ran 500 ms after VimEnter and blocked for ~170 ms with a
-- cold tool cache, 28 features with the mise-managed tools at ~17 ms each.
local M = {}

local linters = require("config.linters")
local lsp_watch = require("config.lsp_watch")
local python_env = require("config.python")
local treesitter = require("config.treesitter")
local tools = require("config.tools")

local notified = {}

-- A feature is either `bins` with a `mode` ("all" of them, or "any" one), or a
-- `check(bufnr)` returning ok and a list of what is missing. `core` features
-- are editor-wide rather than a language's; `per_buffer` marks a check that
-- only means something for a buffer, which the health report skips. Linters
-- take their candidates from config.linters, so this cannot advertise one that
-- nvim-lint would not run (ruff's diagnostics come from its LSP server).
local features = {
  ansible_lsp = {
    label = "Ansible LSP",
    mode = "all",
    bins = { "ansible-language-server" },
  },
  binary_edit = {
    label = "Binary editing",
    core = true,
    mode = "all",
    bins = { "xxd" },
  },
  c_lsp = {
    label = "C/C++ LSP",
    mode = "all",
    bins = { "clangd" },
  },
  core_git = {
    label = "Git integration",
    core = true,
    mode = "all",
    bins = { "git" },
  },
  core_search = {
    label = "Ripgrep search",
    core = true,
    mode = "all",
    bins = { "rg" },
  },
  css_lsp = {
    label = "CSS LSP",
    mode = "all",
    bins = { "vscode-css-language-server" },
  },
  docker_lsp = {
    label = "Dockerfile LSP",
    mode = "all",
    bins = { "docker-langserver" },
  },
  file_watch = {
    label = "LSP file watching",
    core = true,
    check = function()
      if lsp_watch.native_watch_available() then
        return true, {}
      end

      local sysname = (vim.uv or vim.loop).os_uname().sysname
      local remedy = sysname == "FreeBSD" and "inotify-tools port" or "inotify-tools"
      return false, { remedy .. " (off-main-thread file watching)" }
    end,
  },
  gnu_global = {
    label = "GNU Global fallback navigation",
    core = true,
    mode = "all",
    bins = { "global", "gtags" },
  },
  go_format = {
    label = "Go formatting",
    mode = "all",
    bins = { "gofmt", "goimports" },
  },
  go_lsp = {
    label = "Go LSP",
    mode = "all",
    bins = { "gopls" },
  },
  go_runtime = {
    label = "Go toolchain",
    mode = "all",
    bins = { "go" },
  },
  html_lsp = {
    label = "HTML LSP",
    mode = "all",
    bins = { "vscode-html-language-server" },
  },
  java_lsp = {
    label = "Java LSP",
    mode = "all",
    bins = { "jdtls" },
  },
  js_format = {
    label = "JavaScript/TypeScript formatting",
    mode = "any",
    bins = { "prettierd", "prettier" },
  },
  js_lsp = {
    label = "JavaScript/TypeScript LSP",
    mode = "all",
    bins = { "typescript-language-server" },
  },
  json_lsp = {
    label = "JSON LSP",
    mode = "all",
    bins = { "vscode-json-language-server" },
  },
  lua_format = {
    label = "Lua formatting",
    mode = "all",
    bins = { "stylua" },
  },
  lua_lsp = {
    label = "Lua LSP",
    mode = "all",
    bins = { "lua-language-server" },
  },
  markdown_lsp = {
    label = "Markdown LSP",
    mode = "all",
    bins = { "marksman" },
  },
  markdown_view = {
    label = "Markdown terminal view",
    mode = "all",
    bins = { "glow" },
  },
  pyenv = {
    label = "pyenv project environments",
    mode = "all",
    bins = { "pyenv" },
  },
  python_debug = {
    label = "Python debugging",
    check = function(bufnr)
      local status = python_env.module_status("ipdb", bufnr)
      if status.available then
        return true, {}
      end

      return false, { status.detail }
    end,
  },
  python_format = {
    label = "Python formatting",
    mode = "any",
    bins = { "ruff", "black", "yapf", "autopep8" },
  },
  python_lint = {
    label = "Python linting",
    mode = "any",
    bins = linters.candidates("python"),
  },
  python_lsp = {
    label = "Python LSP",
    mode = "all",
    bins = { "pyright-langserver" },
  },
  python_refactor = {
    label = "Python refactoring (pylsp + pylsp-rope)",
    check = function(bufnr)
      local status = python_env.pylsp_status(bufnr)
      if status.available then
        return true, {}
      end

      return false, { status.detail }
    end,
  },
  python_test = {
    label = "Python tests",
    mode = "all",
    bins = { "pytest" },
  },
  python_types = {
    label = "Python type checking",
    mode = "all",
    bins = { "mypy" },
  },
  rust_format = {
    label = "Rust formatting",
    mode = "all",
    bins = { "rustfmt" },
  },
  rust_lsp = {
    label = "Rust LSP",
    mode = "all",
    bins = { "rust-analyzer" },
  },
  shell_format = {
    label = "Shell formatting",
    mode = "all",
    bins = { "shfmt" },
  },
  shell_lint = {
    label = "Shell linting",
    mode = "any",
    bins = linters.candidates("sh"),
  },
  shell_lsp = {
    label = "Shell LSP",
    mode = "all",
    bins = { "bash-language-server" },
  },
  terraform_format = {
    label = "Terraform formatting",
    mode = "all",
    bins = { "terraform" },
  },
  terraform_lint = {
    label = "Terraform linting",
    mode = "any",
    bins = linters.candidates("terraform"),
  },
  terraform_lsp = {
    label = "Terraform LSP",
    mode = "all",
    bins = { "terraform-ls" },
  },
  toml_lsp = {
    label = "TOML LSP and formatting",
    mode = "all",
    bins = { "taplo" },
  },
  treesitter_parser = {
    label = "Treesitter parser",
    per_buffer = true,
    check = function(bufnr)
      local ft = bufnr and vim.bo[bufnr].filetype or vim.bo.filetype
      local missing = treesitter.missing_for_filetype(ft)
      if #missing == 0 then
        return true, {}
      end

      return false, vim.tbl_map(function(lang)
        return lang .. " (:TSInstall " .. lang .. ")"
      end, missing)
    end,
  },
  treesitter_parsers = {
    label = "Treesitter parsers",
    core = true,
    check = function()
      local missing = treesitter.missing_configured()
      if #missing == 0 then
        return true, {}
      end

      return false, {
        table.concat(missing, ", ") .. " (:TSInstall " .. table.concat(missing, " ") .. ")",
      }
    end,
  },
  yaml_lint = {
    label = "YAML linting",
    mode = "any",
    bins = linters.candidates("yaml"),
  },
  yaml_lsp = {
    label = "YAML LSP",
    mode = "all",
    bins = { "yaml-language-server" },
  },
}

-- The features a filetype's workflow needs, checked once on its first buffer.
local filetype_features = {
  bash = { "shell_lsp", "shell_format", "shell_lint" },
  c = { "c_lsp", "gnu_global" },
  cpp = { "c_lsp", "gnu_global" },
  css = { "css_lsp" },
  dockerfile = { "docker_lsp" },
  go = { "go_lsp", "go_runtime", "go_format" },
  html = { "html_lsp", "js_format" },
  java = { "java_lsp", "gnu_global" },
  javascript = { "js_lsp", "js_format" },
  javascriptreact = { "js_lsp", "js_format" },
  json = { "json_lsp", "js_format" },
  jsonc = { "json_lsp", "js_format" },
  less = { "css_lsp" },
  lua = { "lua_lsp", "lua_format" },
  markdown = { "markdown_lsp", "markdown_view" },
  python = { "pyenv", "python_lsp", "python_format", "python_lint", "python_types", "python_test", "python_debug", "python_refactor" },
  rust = { "rust_lsp", "rust_format" },
  scss = { "css_lsp" },
  sh = { "shell_lsp", "shell_format", "shell_lint" },
  terraform = { "terraform_lsp", "terraform_format", "terraform_lint" },
  toml = { "toml_lsp" },
  typescript = { "js_lsp", "js_format" },
  typescriptreact = { "js_lsp", "js_format" },
  yaml = { "yaml_lsp", "yaml_lint" },
  ["yaml.ansible"] = { "ansible_lsp", "yaml_lint" },
  zsh = { "shell_lsp", "shell_format", "shell_lint" },
}

-- ok, the missing tools (or what stands in for them), and the tools found.
local function check_feature(feature, bufnr)
  if type(feature.check) == "function" then
    local ok, missing = feature.check(bufnr)
    return ok, missing, {}
  end

  local found, missing = {}, {}
  for _, bin in ipairs(feature.bins) do
    if tools.available(bin) then
      table.insert(found, bin)
    else
      table.insert(missing, tools.status(bin).detail or bin)
    end
  end

  if feature.mode == "any" then
    if #found > 0 then
      return true, {}, { found[1] }
    end
    return false, missing, {}
  end
  return #missing == 0, missing, found
end

-- One line describing a failed check, in the wording the warnings use.
local function missing_line(feature, missing)
  local prefix = feature.label .. ": "
  if feature.mode == "any" then
    return prefix .. "install one of " .. table.concat(missing, ", ")
  end
  return prefix .. "missing " .. table.concat(missing, ", ")
end

local function collect_lines(feature_ids, bufnr)
  local lines = {}

  for _, id in ipairs(feature_ids) do
    local feature = features[id]
    if feature then
      local ok, missing = check_feature(feature, bufnr)
      if not ok then
        table.insert(lines, missing_line(feature, missing))
      end
    end
  end

  return lines
end

-- Warn about the tools the buffer's filetype workflow is missing. Once per
-- filetype per session, and only with a UI, unless `opts.force`: then the
-- user asked (<leader>cm), so the tools are probed afresh and a clean result
-- is reported too.
function M.check_current_buffer(bufnr, opts)
  bufnr = bufnr or 0
  opts = opts or {}
  local ft = vim.bo[bufnr].filetype
  local title = "Missing " .. ft .. " dependencies"

  local feature_ids = filetype_features[ft]
  if not feature_ids then
    if opts.force then
      vim.notify("No dependency checks for filetype " .. (ft ~= "" and ft or "(none)"), vim.log.levels.INFO)
    end
    return
  end
  feature_ids = vim.list_extend(vim.deepcopy(feature_ids), { "treesitter_parser" })

  if opts.force then
    tools.invalidate()
  else
    -- Latch before checking, not only when something is missing: a check that
    -- found everything installed must not run again, tool probes and all, for
    -- every later buffer of the filetype.
    local key = "ft:" .. ft
    if #vim.api.nvim_list_uis() == 0 or notified[key] then
      return
    end
    notified[key] = true
  end

  local lines = collect_lines(feature_ids, bufnr)
  if #lines == 0 then
    if opts.force then
      vim.notify("All " .. ft .. " dependencies are installed.", vim.log.levels.INFO, { title = title })
    end
    return
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN, { title = title })
end

-- Every feature the health report covers, probed afresh so a tool installed
-- mid-session shows up: `{ core = {...}, languages = {...} }`, each entry
-- `{ id, label, ok, line }` sorted by label, where `line` names the tools found
-- or what is missing. Per-buffer checks are left out; they have no buffer here.
function M.report()
  tools.invalidate()

  local report = { core = {}, languages = {} }
  for id, feature in pairs(features) do
    if not feature.per_buffer then
      local ok, missing, found = check_feature(feature)
      local line = feature.label
      if ok and #found > 0 then
        line = line .. ": " .. table.concat(found, ", ")
      elseif not ok then
        line = missing_line(feature, missing)
      end
      table.insert(feature.core and report.core or report.languages, { id = id, label = feature.label, line = line, ok = ok })
    end
  end

  for _, entries in pairs(report) do
    table.sort(entries, function(a, b)
      return a.label < b.label
    end)
  end
  return report
end

local group = vim.api.nvim_create_augroup("user_deps", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = vim.tbl_keys(filetype_features),
  callback = function(event)
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        M.check_current_buffer(event.buf)
      end
    end, 500)
  end,
  desc = "Warn once per filetype about the workflow's missing tools",
})

return M
