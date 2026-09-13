-- Scoped rename behind <leader>cr and ,rr. Line, function and buffer scopes
-- place multicursor cursors on every whole-word match of the symbol under
-- the cursor; the workspace scope goes to inc-rename's live preview when it
-- is on, else to an LSP rename that counts the edits and asks before applying
-- them.
local M = {}

local lsp_util = require("config.lsp_util")

-- inc-rename's live preview is on unless turned off (<leader>tR).
vim.g.rename_inc_preview = (vim.g.rename_inc_preview ~= false)

local function place_cursors_in_range(bufnr, ident, start_row, end_row, start_col, end_col)
  local mc = require("multicursor-nvim")
  local pat = vim.regex([[\V\<]] .. vim.fn.escape(ident, [[\]]) .. [[\>]])
  mc.action(function(ctx)
    local first = true
    local main = ctx:mainCursor()
    for lnum = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
      local cstart = (lnum == start_row) and (start_col or 0) or 0
      local cend = (lnum == end_row) and (end_col or #line) or #line
      local offset = cstart
      while offset < cend do
        local ms, me = pat:match_str(line:sub(offset + 1, cend))
        if not ms then
          break
        end
        local col = offset + ms
        if first then
          main:setPos({ lnum + 1, col })
          first = false
        else
          ctx:addCursor():setPos({ lnum + 1, col })
        end
        offset = offset + me
      end
    end
  end)
end

-- Cursors on every match of the word under the cursor within `scope`: "line",
-- "function" (the enclosing treesitter function) or "buffer".
function M.multicursor(scope)
  -- expand("<cword>") raises E348 on a blank line rather than returning "".
  local ok, ident = pcall(vim.fn.expand, "<cword>")
  if not ok or ident == "" then
    vim.notify("No symbol under cursor.", vim.log.levels.INFO)
    return
  end

  local bufnr = 0
  if scope == "buffer" then
    place_cursors_in_range(bufnr, ident, 0, vim.api.nvim_buf_line_count(bufnr) - 1)
  elseif scope == "line" then
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    place_cursors_in_range(bufnr, ident, row, row)
  elseif scope == "function" then
    local node = vim.treesitter.get_node()
    while node and node:type() ~= "function_definition" and node:type() ~= "function_declaration" do
      node = node:parent()
    end
    if not node then
      vim.notify("No enclosing function.", vim.log.levels.WARN)
      return
    end
    local srow, scol, erow, ecol = node:range()
    place_cursors_in_range(bufnr, ident, srow, erow, scol, ecol)
  end
end

-- The client to rename with: pyright over pylsp for Python (pylsp advertises
-- renameProvider whether or not a plugin backs it), else the first that
-- offers rename, else nil.
function M.pick_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })
  if #clients == 0 then
    return nil
  end
  for _, c in ipairs(clients) do
    if c.name == "pyright" then
      return c
    end
  end
  return clients[1]
end

local function rename_with_preview()
  vim.ui.input({
    prompt = "New name: ",
    default = vim.fn.expand("<cword>"),
  }, function(new_name)
    if not new_name or new_name == "" then
      return
    end

    local bufnr = 0
    local client = M.pick_client(bufnr)
    if not client then
      vim.notify("No LSP supports rename for this buffer.", vim.log.levels.WARN)
      return
    end
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.newName = new_name

    client:request("textDocument/rename", params, function(err, result)
      if err then
        vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
        return
      end
      if
        not result
        or (not result.changes and not result.documentChanges)
        or (
          result.changes
          and vim.tbl_isempty(result.changes)
          and (not result.documentChanges or vim.tbl_isempty(result.documentChanges))
        )
      then
        vim.notify(
          "Rename failed: no edits returned (symbol may not be renamable here).",
          vim.log.levels.WARN
        )
        return
      end
      local files, total = lsp_util.count_edits(result)
      vim.ui.select({ "Apply", "Cancel" }, {
        prompt = string.format(
          "Rename to '%s': %d edits across %d files\n  %s",
          new_name,
          total,
          #files,
          table.concat(files, "\n  ")
        ),
      }, function(choice)
        if choice == "Apply" then
          vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
          vim.notify(
            string.format("Renamed %d references in %d files.", total, #files),
            vim.log.levels.INFO
          )
        end
      end)
    end, bufnr)
  end)
end

-- Workspace rename: inc-rename's live preview when on and installed, else the
-- count-and-confirm LSP rename.
function M.workspace()
  if vim.g.rename_inc_preview ~= false and pcall(require, "inc_rename") then
    local cword = vim.fn.expand("<cword>")
    -- Deferred feedkeys: the ui.select float needs to close before cmdline
    -- mode takes over, otherwise the keys land in the picker.
    vim.schedule(function()
      vim.api.nvim_feedkeys(":IncRename " .. cword, "n", false)
    end)
  else
    rename_with_preview()
  end
end

-- The scope menu.
function M.dispatch()
  vim.ui.select({
    "Line (multicursor)",
    "Function (multicursor)",
    "Buffer (multicursor)",
    "Workspace (LSP)",
  }, { prompt = "Rename scope:" }, function(choice)
    if not choice then
      return
    end
    if choice:find("^Workspace") then
      M.workspace()
    elseif choice:find("^Line") then
      M.multicursor("line")
    elseif choice:find("^Function") then
      M.multicursor("function")
    elseif choice:find("^Buffer") then
      M.multicursor("buffer")
    end
  end)
end

function M.toggle_preview()
  vim.g.rename_inc_preview = not vim.g.rename_inc_preview
  vim.notify(
    "inc-rename live preview " .. (vim.g.rename_inc_preview and "enabled" or "disabled"),
    vim.log.levels.INFO
  )
end

return M
