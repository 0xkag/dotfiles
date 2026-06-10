-- Terraform code-mode helpers: validate, lint, fmt-check, open-file-at-point.
local M = {}

local shared = require("config.code_mode.shared")
local util = require("config.util")

function M.terraform_validate()
  shared.project_command("terraform validate", "terraform validate -no-color", {
    last_key = "terraform_validate",
  })
end

function M.terraform_lint()
  shared.project_command("tflint", "tflint --format compact", {
    last_key = "terraform_lint",
  })
end

function M.terraform_fmt_check()
  shared.project_command("terraform fmt", "terraform fmt -check -diff=false", {
    last_key = "terraform_fmt",
  })
end

-- Expand the terraform path references this config can resolve statically:
-- ${path.module} -> the module directory (dir of the current file) and
-- ${path.root}/${path.cwd} -> the project root. Whitespace inside the
-- interpolation braces is tolerated (terraform allows `${ path.module }`).
-- Returns nil when the string still contains an interpolation we cannot
-- resolve (e.g. ${var.name}), since the real path is only known at plan time.
---@param raw string
---@param ctx { module_dir: string, root: string }
---@return string?
function M.expand_interpolations(raw, ctx)
  local out = raw:gsub("%${%s*path%.module%s*}", ctx.module_dir)
    :gsub("%${%s*path%.root%s*}", ctx.root)
    :gsub("%${%s*path%.cwd%s*}", ctx.root)

  if out:find("%${") then
    return nil
  end

  return out
end

-- Resolve a (possibly relative) path to an existing filesystem entry. Absolute
-- paths are taken as-is; relative paths are tried against the module directory
-- first, then the project root. Returns the normalized path and its type
-- ("file" or "directory") for the first candidate that exists, or nil. A
-- directory is a valid result: a terraform module `source` points at a module
-- directory. `stat` is injectable for testing; it defaults to vim.uv.fs_stat.
---@param path string
---@param ctx { module_dir: string, root: string }
---@param stat? fun(p: string): table?
---@return string? path, string? type
function M.resolve_candidate(path, ctx, stat)
  stat = stat or (vim.uv or vim.loop).fs_stat

  local candidates = {}
  if path:sub(1, 1) == "/" then
    table.insert(candidates, path)
  else
    table.insert(candidates, vim.fs.joinpath(ctx.module_dir, path))
    table.insert(candidates, vim.fs.joinpath(ctx.root, path))
  end

  for _, candidate in ipairs(candidates) do
    local normalized = vim.fs.normalize(candidate)
    local info = stat(normalized)
    if info and (info.type == "file" or info.type == "directory") then
      return normalized, info.type
    end
  end

  return nil
end

-- The terraform entry file to open for a module directory: prefer main.tf,
-- then the first *.tf alphabetically, else nil (caller opens the dir itself).
---@param dir string
---@return string?
function M.module_entry_file(dir)
  local main = vim.fs.joinpath(dir, "main.tf")
  if (vim.uv or vim.loop).fs_stat(main) then
    return main
  end

  local tf_files = {}
  for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("%.tf$") then
      table.insert(tf_files, name)
    end
  end
  if #tf_files == 0 then
    return nil
  end

  table.sort(tf_files)
  return vim.fs.joinpath(dir, tf_files[1])
end

-- The literal text of the string under the cursor. Terraform inherits HCL
-- nodes; a string is a `quoted_template` (or `string_lit`) whose children
-- include `template_literal` runs and `${...}` `template_interpolation`s. We
-- take the whole node's inner text (interpolations included) so
-- expand_interpolations can resolve them. Falls back to <cfile> when no string
-- node is found (matches markdown_follow_thing).
---@return string?
local function string_under_cursor()
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    -- Walk to the outermost string wrapper, not the first match: the cursor's
    -- node may be an inner `template_literal` run (the text after a `${...}`),
    -- and returning that would drop the interpolation prefix. quoted_template /
    -- string_lit are the whole-string nodes; template_literal is only used if
    -- no wrapper is present in the ancestry.
    local wrapper, literal = nil, nil
    while node do
      local t = node:type()
      if t == "quoted_template" or t == "string_lit" then
        wrapper = node
      elseif t == "template_literal" and not literal then
        literal = node
      end
      node = node:parent()
    end

    local best = wrapper or literal
    if best then
      local text = vim.treesitter.get_node_text(best, 0)
      -- Strip surrounding quotes if the matched node carries them.
      return (text:gsub('^"', ""):gsub('"$', ""))
    end
  end

  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then
    return cfile
  end

  return nil
end

-- Jump to the document link covering the cursor, if terraform-ls offers one.
-- Used as a fallback for module `source` addresses, which the server links via
-- textDocument/documentLink (local file-path args are not linked, hence the
-- static resolver above). Returns true if a link was opened.
---@return boolean
local function follow_document_link()
  local params = { textDocument = vim.lsp.util.make_text_document_params() }
  local results = vim.lsp.buf_request_sync(0, "textDocument/documentLink", params, 500)
  if not results then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  for _, result in pairs(results) do
    for _, link in ipairs(result.result or {}) do
      local s, e = link.range.start, link.range["end"]
      local after_start = row > s.line or (row == s.line and col >= s.character)
      local before_end = row < e.line or (row == e.line and col <= e.character)
      if link.target and after_start and before_end then
        vim.ui.open(link.target)
        return true
      end
    end
  end

  return false
end

-- Open the file or module named under the cursor: resolve a path string
-- (expanding ${path.module}/${path.root}) and :edit it. A path resolving to a
-- directory is a module `source`, so open its entry file (main.tf or the first
-- *.tf), or the directory itself if it holds no terraform files. Falls back to
-- following an LSP document link, then a notify.
function M.terraform_open_file()
  local raw = string_under_cursor()
  if not raw then
    if not follow_document_link() then
      vim.notify("No file or link under cursor.", vim.log.levels.INFO)
    end
    return
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  local ctx = {
    module_dir = bufname ~= "" and vim.fs.dirname(bufname) or util.cwd(),
    root = util.project_root(0),
  }

  local expanded = M.expand_interpolations(raw, ctx)
  if expanded then
    local resolved, kind = M.resolve_candidate(expanded, ctx)
    if resolved then
      local target = resolved
      if kind == "directory" then
        target = M.module_entry_file(resolved) or resolved
      end
      vim.cmd.edit(vim.fn.fnameescape(target))
      return
    end
  end

  if not follow_document_link() then
    vim.notify("No file or link under cursor: " .. raw, vim.log.levels.INFO)
  end
end

return M
