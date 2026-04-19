local M = {}

local notified = {}
local python_env = require("config.python")
local tools = require("config.tools")

local features = {
  core_git = {
    label = "Git integration",
    mode = "all",
    bins = { "git" },
  },
  core_search = {
    label = "Ripgrep search",
    mode = "all",
    bins = { "rg" },
  },
  binary_edit = {
    label = "Binary editing",
    mode = "all",
    bins = { "xxd" },
  },
  gnu_global = {
    label = "GNU Global fallback navigation",
    mode = "all",
    bins = { "global", "gtags" },
  },
  pyenv = {
    label = "pyenv project environments",
    mode = "all",
    bins = { "pyenv" },
  },
  python_lsp = {
    label = "Python LSP",
    mode = "all",
    bins = { "pyright-langserver" },
  },
  python_format = {
    label = "Python formatting",
    mode = "any",
    bins = { "ruff", "black", "yapf" },
  },
  python_lint = {
    label = "Python linting",
    mode = "any",
    bins = { "ruff", "pylint", "flake8" },
  },
  python_types = {
    label = "Python type checking",
    mode = "all",
    bins = { "mypy" },
  },
  python_test = {
    label = "Python tests",
    mode = "all",
    bins = { "pytest" },
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
  go_format = {
    label = "Go formatting",
    mode = "all",
    bins = { "gofmt", "goimports" },
  },
  rust_lsp = {
    label = "Rust LSP",
    mode = "all",
    bins = { "rust-analyzer" },
  },
  rust_format = {
    label = "Rust formatting",
    mode = "all",
    bins = { "rustfmt" },
  },
  c_lsp = {
    label = "C/C++ LSP",
    mode = "all",
    bins = { "clangd" },
  },
  java_lsp = {
    label = "Java LSP",
    mode = "all",
    bins = { "jdtls" },
  },
  js_lsp = {
    label = "JavaScript/TypeScript LSP",
    mode = "all",
    bins = { "typescript-language-server" },
  },
  js_format = {
    label = "JavaScript/TypeScript formatting",
    mode = "any",
    bins = { "prettierd", "prettier" },
  },
  html_lsp = {
    label = "HTML LSP",
    mode = "all",
    bins = { "vscode-html-language-server" },
  },
  shell_lsp = {
    label = "Shell LSP",
    mode = "all",
    bins = { "bash-language-server" },
  },
  shell_format = {
    label = "Shell formatting",
    mode = "all",
    bins = { "shfmt" },
  },
  shell_lint = {
    label = "Shell linting",
    mode = "all",
    bins = { "shellcheck" },
  },
  markdown_lsp = {
    label = "Markdown LSP",
    mode = "all",
    bins = { "marksman" },
  },
  terraform_lsp = {
    label = "Terraform LSP",
    mode = "all",
    bins = { "terraform-ls" },
  },
  terraform_format = {
    label = "Terraform formatting",
    mode = "all",
    bins = { "terraform" },
  },
  terraform_lint = {
    label = "Terraform linting",
    mode = "all",
    bins = { "tflint" },
  },
  yaml_lsp = {
    label = "YAML LSP",
    mode = "all",
    bins = { "yaml-language-server" },
  },
  yaml_lint = {
    label = "YAML linting",
    mode = "all",
    bins = { "yamllint" },
  },
  json_lsp = {
    label = "JSON LSP",
    mode = "all",
    bins = { "vscode-json-language-server" },
  },
  lua_lsp = {
    label = "Lua LSP",
    mode = "all",
    bins = { "lua-language-server" },
  },
  lua_format = {
    label = "Lua formatting",
    mode = "all",
    bins = { "stylua" },
  },
}

local core_features = {
  "core_git",
  "core_search",
  "binary_edit",
}

local filetype_features = {
  bash = { "shell_lsp", "shell_format", "shell_lint" },
  c = { "c_lsp", "gnu_global" },
  cpp = { "c_lsp", "gnu_global" },
  go = { "go_lsp", "go_runtime", "go_format" },
  html = { "html_lsp", "js_format" },
  java = { "java_lsp", "gnu_global" },
  javascript = { "js_lsp", "js_format" },
  javascriptreact = { "js_lsp", "js_format" },
  json = { "json_lsp", "js_format" },
  jsonc = { "json_lsp", "js_format" },
  lua = { "lua_lsp", "lua_format" },
  markdown = { "markdown_lsp" },
  python = { "pyenv", "python_lsp", "python_format", "python_lint", "python_types", "python_test", "python_debug" },
  rust = { "rust_lsp", "rust_format" },
  sh = { "shell_lsp", "shell_format", "shell_lint" },
  terraform = { "terraform_lsp", "terraform_format", "terraform_lint" },
  typescript = { "js_lsp", "js_format" },
  typescriptreact = { "js_lsp", "js_format" },
  yaml = { "yaml_lsp", "yaml_lint" },
  zsh = { "shell_lsp", "shell_format", "shell_lint" },
}

local all_features = {
  "core_git",
  "core_search",
  "binary_edit",
  "gnu_global",
  "pyenv",
  "python_lsp",
  "python_format",
  "python_lint",
  "python_types",
  "python_test",
  "python_debug",
  "go_lsp",
  "go_runtime",
  "go_format",
  "rust_lsp",
  "rust_format",
  "c_lsp",
  "java_lsp",
  "js_lsp",
  "js_format",
  "html_lsp",
  "shell_lsp",
  "shell_format",
  "shell_lint",
  "markdown_lsp",
  "terraform_lsp",
  "terraform_format",
  "terraform_lint",
  "yaml_lsp",
  "yaml_lint",
  "json_lsp",
  "lua_lsp",
  "lua_format",
}

local startup_features = {
  "core_git",
  "core_search",
  "binary_edit",
  "gnu_global",
  "go_lsp",
  "go_runtime",
  "go_format",
  "rust_lsp",
  "rust_format",
  "c_lsp",
  "java_lsp",
  "js_lsp",
  "js_format",
  "html_lsp",
  "shell_lsp",
  "shell_format",
  "shell_lint",
  "markdown_lsp",
  "terraform_lsp",
  "terraform_format",
  "terraform_lint",
  "yaml_lsp",
  "yaml_lint",
  "json_lsp",
  "lua_lsp",
  "lua_format",
}

local function executable(bin)
  return bin ~= nil and bin ~= "" and tools.available(bin)
end

local function check_feature(feature, bufnr)
  if type(feature.check) == "function" then
    return feature.check(bufnr)
  end

  if feature.mode == "any" then
    for _, bin in ipairs(feature.bins) do
      if executable(bin) then
        return true, {}
      end
    end

    local missing = {}
    for _, bin in ipairs(feature.bins) do
      table.insert(missing, tools.status(bin).detail or bin)
    end
    return false, missing
  end

  local missing = {}
  for _, bin in ipairs(feature.bins) do
    if not executable(bin) then
      table.insert(missing, tools.status(bin).detail or bin)
    end
  end

  return #missing == 0, missing
end

local function collect_lines(feature_ids, bufnr)
  local lines = {}

  for _, id in ipairs(feature_ids) do
    local feature = features[id]
    if feature then
      local ok, missing = check_feature(feature, bufnr)
      if not ok then
        local prefix = feature.label .. ": "
        if feature.mode == "any" then
          table.insert(lines, prefix .. "install one of " .. table.concat(missing, ", "))
        else
          table.insert(lines, prefix .. "missing " .. table.concat(missing, ", "))
        end
      end
    end
  end

  return lines
end

local function notify_once(feature_ids, title, key, bufnr)
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  if notified[key] then
    return
  end

  local lines = collect_lines(feature_ids, bufnr)
  if #lines == 0 then
    return
  end

  notified[key] = true
  vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN, {
    title = title,
  })
end

function M.check_current_buffer(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  local feature_ids = filetype_features[ft]
  if not feature_ids then
    return
  end

  notify_once(feature_ids, "Missing " .. ft .. " dependencies", "ft:" .. ft, bufnr)
end

function M.command(scope)
  local feature_ids = all_features
  local title = "Missing dependencies"

  if scope == "current" then
    feature_ids = vim.list_extend(vim.deepcopy(core_features), filetype_features[vim.bo.filetype] or {})
    title = "Missing current-buffer dependencies"
  end

  local lines = collect_lines(feature_ids, scope == "current" and 0 or nil)
  if #lines == 0 then
    vim.notify("All checked dependencies are installed.", vim.log.levels.INFO, {
      title = title,
    })
    return
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN, {
    title = title,
  })
end

vim.api.nvim_create_user_command("NvimDeps", function(command)
  local scope = command.args ~= "" and command.args or "all"
  M.command(scope)
end, {
  complete = function()
    return { "all", "current" }
  end,
  desc = "Show missing external dependencies",
  nargs = "?",
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      notify_once(startup_features, "Missing PATH dependencies", "startup")
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = vim.tbl_keys(filetype_features),
  callback = function(event)
    vim.schedule(function()
      M.check_current_buffer(event.buf)
    end)
  end,
})

return M
