-- Pure helpers extracted from lua/plugins/lsp.lua so they can be unit-tested
-- headless (see test/lsp_util_spec.lua). These do no buffer mutation: they
-- transform signature-parameter label strings and summarize workspace-edit
-- results. The side-effectful wiring (cursor placement, snippet expansion,
-- buffer probing) stays inline in lsp.lua where it has the LspAttach context.
local M = {}

-- Turn a signature parameter label into a "name=default" placeholder body for
-- the positional call template, stripping type annotations.
--   "x: int = 3"  -> "x=3"
--   "y=5"         -> "y=5"
--   "z: int"      -> "z"
--   "w"           -> "w"
function M.clean_label(raw)
  local name, default = raw:match("^%s*([^:=]-)%s*:.-=%s*(.*)$")
  if name and name ~= "" then
    return name .. "=" .. default
  end
  name, default = raw:match("^%s*([^:=]-)%s*=%s*(.*)$")
  if name and name ~= "" then
    return name .. "=" .. default
  end
  local no_type = raw:match("^%s*([^:]+)%s*:")
  if no_type then
    return vim.trim(no_type)
  end
  return vim.trim(raw)
end

-- The bare identifier of a parameter label, ignoring leading */** and types.
--   "*args"       -> "args"
--   "x: int = 1"  -> "x"
function M.bare_name(raw)
  local stripped = raw:match("^%s*%*?%*?([%w_]+)")
  return stripped or vim.trim(raw)
end

-- Whether a parameter can be passed by keyword (excludes the bare "*" / "/"
-- separators and *args / **kwargs forms).
function M.is_kwargable(raw)
  local trimmed = vim.trim(raw)
  return trimmed ~= "*" and trimmed ~= "/" and not trimmed:match("^%*")
end

-- Resolve a parameter's label, which an LSP may give either as a literal string
-- or as a [start, end) offset pair into the signature's own label string.
function M.param_label(sig, param)
  if type(param.label) == "table" then
    return sig.label:sub(param.label[1] + 1, param.label[2])
  end
  return param.label
end

-- Summarize a workspace-edit `result`: the list of touched filenames and the
-- total number of individual text edits, across both the `changes` and
-- `documentChanges` shapes.
function M.count_edits(result)
  local files, total = {}, 0
  for uri, edits in pairs(result.changes or {}) do
    table.insert(files, vim.uri_to_fname(uri))
    total = total + #edits
  end
  for _, c in ipairs(result.documentChanges or {}) do
    if c.textDocument then
      table.insert(files, vim.uri_to_fname(c.textDocument.uri))
      total = total + #(c.edits or {})
    end
  end
  return files, total
end

-- A vim.lsp.config `cmd` function that resolves the server command per root
-- when the client starts. vim.lsp.config has no on_new_config hook, so a
-- command that depends on the workspace, such as a project venv's pylsp over
-- the pipx one, cannot be a static list: that is evaluated once, with no root.
-- `resolve(root_dir)` returns the argv list.
function M.lazy_cmd(resolve)
  return function(dispatchers, config)
    return vim.lsp.rpc.start(resolve(config.root_dir), dispatchers)
  end
end

-- Remove from pylsp's server_capabilities everything pyright and ruff own.
-- pylsp advertises a provider for every plugin slot whether or not the plugin
-- is enabled in settings, so left alone it would win rename, hover,
-- definitions and the rest over the clients that actually implement them.
-- Only codeActionProvider survives, matching pylsp's job here: rope refactors.
-- Mutates and returns `caps`; meant for on_init, which runs once per client
-- after the capabilities are set and before any LspAttach handler reads them.
function M.strip_pylsp_capabilities(caps)
  if not caps then
    return caps
  end

  caps.completionProvider = nil
  caps.declarationProvider = false
  caps.definitionProvider = false
  caps.documentHighlightProvider = false
  caps.documentSymbolProvider = false
  caps.hoverProvider = false
  caps.implementationProvider = false
  caps.referencesProvider = false
  caps.renameProvider = false
  caps.signatureHelpProvider = nil
  caps.typeDefinitionProvider = false
  caps.workspaceSymbolProvider = false
  return caps
end

return M
