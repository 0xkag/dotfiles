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

return M
