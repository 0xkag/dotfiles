-- Guard against Neovim's pure-Lua LSP file-watch backend hanging the main
-- thread in very large workspaces.
--
-- Background: when a server registers `workspace/didChangeWatchedFiles` and the
-- active watch backend is `watchdirs` (the fallback used when no inotifywait is
-- on PATH and we are not on macOS/Windows), Neovim walks the entire workspace
-- root and creates one `uv_fs_event` per directory on the main loop. In a
-- monorepo with tens of thousands of directories that pins a core indefinitely.
--
-- Native backends do not have this problem: macOS/Windows use a single
-- recursive watcher, and inotifywait runs the recursive watch in an external
-- process. So we only intervene for the watchdirs backend on a huge tree.
--
-- The pure helpers (backend, tree_is_huge, native_watch_available) are unit
-- tested headless; the side-effectful wiring (maybe_suppress,
-- install_git_head_refresh) is exercised interactively. See
-- test/lsp_watch_spec.lua.
local M = {}

local uv = vim.uv or vim.loop

-- Directory count above which the watchdirs backend is considered too expensive
-- to let recurse on the main thread.
local HUGE_TREE_DIRS = 2000

-- Debounce window for the .git/HEAD refresh, so a branch switch that rewrites
-- HEAD several times in quick succession triggers a single LspRestart.
local HEAD_REFRESH_DEBOUNCE_MS = 1500

-- fs_event handles and debounce timers, keyed by client id, so we can close
-- them on LspDetach and avoid leaking watchers across restarts.
local head_watchers = {}

-- Whether the user has been warned about the missing native watch dependency.
local notified_missing_dep = false

--- Resolve which file-watch backend Neovim will use, mirroring the selection in
--- runtime/lua/vim/lsp/_watchfiles.lua. Returns one of "fsevent", "inotify",
--- "watchdirs". We re-derive the decision rather than read the private
--- `_watchfunc` so this keeps working if that internal is renamed.
---@return string
function M.backend()
  if vim.fn.has("win32") == 1 or vim.fn.has("mac") == 1 then
    return "fsevent"
  end
  if vim.fn.executable("inotifywait") == 1 then
    return "inotify"
  end
  return "watchdirs"
end

--- Whether the active backend watches without a main-thread recursive walk.
---@return boolean
function M.native_watch_available()
  return M.backend() ~= "watchdirs"
end

--- Count directories under `root` (depth-limited like the watchdirs walk),
--- stopping as soon as `cap` is exceeded. Uses vim.fs.dir's lazy coroutine
--- iterator so the early break is cheap on enormous trees.
---@param root string
---@param cap integer? Directory count to exceed (default HUGE_TREE_DIRS).
---@return boolean
function M.tree_is_huge(root, cap)
  cap = cap or HUGE_TREE_DIRS
  local count = 0
  local ok = pcall(function()
    for _, type in vim.fs.dir(root, { depth = 100 }) do
      if type == "directory" then
        count = count + 1
        if count > cap then
          error("huge")
        end
      end
    end
  end)

  -- pcall returns false either because we hit the cap (count > cap) or because
  -- of a real filesystem error; only the former means "huge".
  return not ok and count > cap
end

--- Workspace base directories for a client: prefer the registered workspace
--- folders, falling back to the resolved root_dir.
---@param client vim.lsp.Client
---@return string[]
local function client_roots(client)
  local roots = {}
  for _, folder in ipairs(client.workspace_folders or {}) do
    if folder.uri then
      table.insert(roots, vim.uri_to_fname(folder.uri))
    end
  end
  if #roots == 0 and client.root_dir then
    table.insert(roots, client.root_dir)
  end
  return roots
end

--- Start a single fs_event on `<root>/.git/HEAD` that restarts the client
--- (debounced) when the branch changes, so the server re-indexes after a
--- checkout even though we declined its recursive watcher. Worktrees and
--- submodules store .git as a file rather than a directory; we skip those
--- (best effort -- the user can :LspRestart manually).
---@param client vim.lsp.Client
---@param roots string[]
function M.install_git_head_refresh(client, roots)
  if head_watchers[client.id] then
    return
  end

  local handles = {}
  local timer = nil

  for _, root in ipairs(roots) do
    local git_dir = root .. "/.git"
    local head = git_dir .. "/HEAD"
    local git_stat = uv.fs_stat(git_dir)
    if git_stat and git_stat.type == "directory" and uv.fs_stat(head) then
      local handle = uv.new_fs_event()
      local ok = handle:start(head, {}, function()
        if timer then
          timer:stop()
          timer:close()
        end
        timer = uv.new_timer()
        timer:start(HEAD_REFRESH_DEBOUNCE_MS, 0, function()
          timer:stop()
          timer:close()
          timer = nil
          vim.schedule(function()
            if vim.lsp.get_client_by_id(client.id) then
              vim.cmd("LspRestart " .. client.name)
            end
          end)
        end)
      end)
      if ok then
        table.insert(handles, handle)
      else
        handle:close()
      end
    end
  end

  if #handles > 0 then
    head_watchers[client.id] = { handles = handles }
  end
end

--- Close and forget any HEAD watchers for a client.
---@param client_id integer
function M.cleanup(client_id)
  local entry = head_watchers[client_id]
  if not entry then
    return
  end
  for _, handle in ipairs(entry.handles) do
    if not handle:is_closing() then
      handle:close()
    end
  end
  head_watchers[client_id] = nil
end

--- Decline the recursive watcher for `client` when (and only when) the active
--- backend is watchdirs and the workspace tree is huge. Mutates
--- `client.capabilities`, which the watcher-registration guard reads after
--- on_init, so the recursive walk never starts. Installs the .git/HEAD refresh
--- hook and warns once about the missing native dependency.
---@param client vim.lsp.Client
function M.maybe_suppress(client)
  if M.backend() ~= "watchdirs" then
    return
  end

  local roots = client_roots(client)
  local huge = false
  for _, root in ipairs(roots) do
    if M.tree_is_huge(root) then
      huge = true
      break
    end
  end
  if not huge then
    return
  end

  client.capabilities = vim.tbl_deep_extend("force", client.capabilities or {}, {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = false,
      },
    },
  })

  M.install_git_head_refresh(client, roots)

  if not notified_missing_dep and #vim.api.nvim_list_uis() > 0 then
    notified_missing_dep = true
    vim.notify(
      "LSP file watching disabled for "
        .. client.name
        .. " in a large workspace (no native file-watch backend). Install "
        .. "inotify-tools for live external-change detection; branch switches "
        .. "still refresh via .git/HEAD.",
      vim.log.levels.WARN,
      { title = "LSP file watching" }
    )
  end
end

return M
