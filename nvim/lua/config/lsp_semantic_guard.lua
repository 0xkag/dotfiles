-- Bound a runaway loop in Neovim's LSP semantic-tokens highlighter.
--
-- runtime/lua/vim/lsp/semantic_tokens.lua converts a server's token stream into
-- highlight ranges. For each token it computes
--
--   end_char = start_char + length          -- start_char accumulates deltaStart
--   while new_end_char > 0 do
--     ...
--     buf_line = lines[end_line + 1] or ''   -- '' past end-of-buffer
--     new_end_char = new_end_char - str_utfindex(buf_line) - eol_offset
--   end
--
-- Past end-of-buffer `buf_line` is '' so str_utfindex is 0 and new_end_char
-- only drops by eol_offset (1) per iteration. terraform-ls in a large workspace
-- emits a token whose `deltaStart` is a small negative value encoded as an
-- unsigned 32-bit int (observed 4294967253 == 2^32 - 43). That makes start_char
-- -- and hence end_char -- astronomical, so the loop runs billions of times on
-- the main thread: Neovim pins a core and stops responding, even to SIGTERM.
--
-- The LSP spec requires a semantic token to stay within a single line, so both
-- a valid `deltaStart` and a valid `length` never exceed their line's length,
-- which never exceeds the buffer's longest line (in bytes, a safe upper bound
-- on the encoding's code-unit count). Clamping those two fields to that maximum
-- is a no-op for spec-compliant servers and converts the malformed case from
-- "spin forever" into a bounded, terminating walk.
--
-- We patch the one reachable seam -- STHighlighter:process_response, exposed as
-- M.__STHighlighter -- and degrade to a no-op if a future Neovim changes the
-- internals. The clamp itself (clamp_data) is pure and unit tested. See
-- test/lsp_semantic_guard_spec.lua.
local M = {}

local applied = false

--- Longest line length (in bytes) of a buffer; a safe upper bound on any
--- valid token length, since byte count >= code-unit count >= a single-line
--- token's length.
---@param bufnr integer
---@return integer
function M.max_line_length(bufnr)
  local max = 0
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      if #line > max then
        max = #line
      end
    end
  end
  return max
end

--- Clamp the `deltaStart` and `length` fields of each token in a
--- semantic-tokens data array to `max_len`. Token data is a flat array of
--- 5-tuples {deltaLine, deltaStartChar, length, tokenType, tokenModifiers};
--- deltaStartChar is the 2nd element and length the 3rd. A malformed value
--- (e.g. a negative delta wrapped to a huge uint32) in either field drives the
--- highlighter's range loop billions of iterations. Mutates and returns `data`.
---@param data integer[]?
---@param max_len integer
---@return integer[]?
function M.clamp_data(data, max_len)
  if type(data) ~= "table" then
    return data
  end
  for i = 1, #data, 5 do
    local delta_start = data[i + 1]
    if type(delta_start) == "number" and delta_start > max_len then
      data[i + 1] = max_len
    end
    local length = data[i + 2]
    if type(length) == "number" and length > max_len then
      data[i + 2] = max_len
    end
  end
  return data
end

--- Sanitize a process_response `response`, clamping both the full-result
--- `data` and any delta `edits[].data`.
---@param response table?
---@param max_len integer
local function sanitize_response(response, max_len)
  if type(response) ~= "table" then
    return
  end
  if response.data then
    M.clamp_data(response.data, max_len)
  end
  if response.edits then
    for _, edit in ipairs(response.edits) do
      M.clamp_data(edit.data, max_len)
    end
  end
end

--- Install the guard by wrapping STHighlighter:process_response. Idempotent;
--- no-ops if the runtime internals are not in the expected shape.
function M.apply()
  if applied then
    return
  end

  local ok, semantic_tokens = pcall(require, "vim.lsp.semantic_tokens")
  if not ok then
    return
  end

  local STHighlighter = semantic_tokens.__STHighlighter
  if type(STHighlighter) ~= "table" or type(STHighlighter.process_response) ~= "function" then
    return
  end

  local original = STHighlighter.process_response
  STHighlighter.process_response = function(self, response, ...)
    pcall(function()
      sanitize_response(response, M.max_line_length(self.bufnr))
    end)
    return original(self, response, ...)
  end

  applied = true
end

return M
