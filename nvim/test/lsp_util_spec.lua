-- Headless test harness for config.lsp_util pure helpers.
-- Run: nvim --headless -u NONE -l nvim/test/lsp_util_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_util_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

local lsp_util = require("config.lsp_util")

-- clean_label(): name=default placeholder body, types stripped.
do
  check("clean_label type+default", lsp_util.clean_label("x: int = 3") == "x=3", lsp_util.clean_label("x: int = 3"))
  check("clean_label default only", lsp_util.clean_label("y=5") == "y=5", lsp_util.clean_label("y=5"))
  check("clean_label type only", lsp_util.clean_label("z: int") == "z", lsp_util.clean_label("z: int"))
  check("clean_label bare", lsp_util.clean_label("w") == "w", lsp_util.clean_label("w"))
  check("clean_label trims bare", lsp_util.clean_label("  q  ") == "q", "[" .. lsp_util.clean_label("  q  ") .. "]")
end

-- bare_name(): identifier with leading */** and type/default stripped.
do
  check("bare_name plain", lsp_util.bare_name("x") == "x", lsp_util.bare_name("x"))
  check("bare_name with type", lsp_util.bare_name("x: int = 1") == "x", lsp_util.bare_name("x: int = 1"))
  check("bare_name star args", lsp_util.bare_name("*args") == "args", lsp_util.bare_name("*args"))
  check("bare_name double star", lsp_util.bare_name("**kwargs") == "kwargs", lsp_util.bare_name("**kwargs"))
end

-- is_kwargable(): excludes separators and *args/**kwargs.
do
  check("is_kwargable normal", lsp_util.is_kwargable("x: int") == true)
  check("is_kwargable rejects star sep", lsp_util.is_kwargable("*") == false)
  check("is_kwargable rejects slash sep", lsp_util.is_kwargable("/") == false)
  check("is_kwargable rejects *args", lsp_util.is_kwargable("*args") == false)
  check("is_kwargable rejects **kwargs", lsp_util.is_kwargable("**kwargs") == false)
end

-- param_label(): literal string label, or offset pair into sig.label.
do
  check("param_label literal string", lsp_util.param_label({ label = "f(a, b)" }, { label = "a" }) == "a")
  -- Offsets are [start, end) into the signature label; LSP start is 0-based.
  local sig = { label = "f(alpha, beta)" }
  local got = lsp_util.param_label(sig, { label = { 2, 7 } })
  check("param_label offset pair", got == "alpha", got)
end

-- count_edits(): totals files + edits across changes and documentChanges.
do
  local files, total = lsp_util.count_edits({
    changes = {
      ["file:///a.lua"] = { {}, {} },
      ["file:///b.lua"] = { {} },
    },
  })
  check("count_edits changes file count", #files == 2, #files)
  check("count_edits changes total", total == 3, total)

  local files2, total2 = lsp_util.count_edits({
    documentChanges = {
      { textDocument = { uri = "file:///c.lua" }, edits = { {}, {}, {} } },
      { textDocument = { uri = "file:///d.lua" }, edits = { {} } },
    },
  })
  check("count_edits docChanges file count", #files2 == 2, #files2)
  check("count_edits docChanges total", total2 == 4, total2)

  local f3, t3 = lsp_util.count_edits({})
  check("count_edits empty files", #f3 == 0, #f3)
  check("count_edits empty total", t3 == 0, t3)
end

-- lazy_cmd(): a vim.lsp.config `cmd` function that resolves the command per
-- root at start time. vim.lsp.config has no on_new_config hook, so a command
-- that depends on the workspace (a project venv's pylsp over the pipx one) has
-- to be resolved here; a static `cmd` is evaluated once, with no root.
do
  local started = {}
  local rpc_start = vim.lsp.rpc.start
  vim.lsp.rpc.start = function(cmd, dispatchers)
    table.insert(started, { cmd = cmd, dispatchers = dispatchers })
    return "client-" .. #started
  end

  local roots = {}
  local cmd = lsp_util.lazy_cmd(function(root_dir)
    table.insert(roots, root_dir)
    return { "/venv/" .. tostring(root_dir) .. "/bin/pylsp" }
  end)
  check("lazy_cmd returns a function", type(cmd) == "function", type(cmd))

  local dispatchers = { notification = function() end }
  local result = cmd(dispatchers, { root_dir = "/proj/a" })
  check("lazy_cmd resolves with the config root", roots[1] == "/proj/a", vim.inspect(roots))
  check("lazy_cmd starts the resolved command", started[1] and started[1].cmd[1] == "/venv//proj/a/bin/pylsp", vim.inspect(started))
  check("lazy_cmd passes the dispatchers through", started[1] and started[1].dispatchers == dispatchers)
  check("lazy_cmd returns the rpc client", result == "client-1", result)

  cmd(dispatchers, { root_dir = "/proj/b" })
  check("lazy_cmd resolves again for another root", roots[2] == "/proj/b", vim.inspect(roots))
  check("lazy_cmd resolves a nil root", cmd(dispatchers, {}) == "client-3" and roots[3] == nil, vim.inspect(roots))

  vim.lsp.rpc.start = rpc_start
end

-- strip_pylsp_capabilities(): pylsp advertises a provider for every plugin slot
-- whether or not the plugin is enabled, so everything pyright and ruff own is
-- removed from its server_capabilities and only code actions (rope refactors)
-- survive. Runs from on_init: the runtime fires LspAttach before on_attach, so
-- an on_attach strip left every LspAttach handler seeing the unstripped set.
do
  local code_actions = { codeActionKinds = { "refactor" } }
  local caps = {
    codeActionProvider = code_actions,
    completionProvider = { triggerCharacters = { "." } },
    declarationProvider = true,
    definitionProvider = true,
    documentHighlightProvider = true,
    documentSymbolProvider = true,
    executeCommandProvider = { commands = { "x" } },
    hoverProvider = true,
    implementationProvider = true,
    referencesProvider = true,
    renameProvider = { prepareProvider = true },
    signatureHelpProvider = { triggerCharacters = { "(" } },
    textDocumentSync = 2,
    typeDefinitionProvider = true,
    workspaceSymbolProvider = true,
  }
  local returned = lsp_util.strip_pylsp_capabilities(caps)
  check("strip returns the same table", returned == caps)
  for _, name in ipairs({
    "completionProvider",
    "declarationProvider",
    "definitionProvider",
    "documentHighlightProvider",
    "documentSymbolProvider",
    "hoverProvider",
    "implementationProvider",
    "referencesProvider",
    "renameProvider",
    "signatureHelpProvider",
    "typeDefinitionProvider",
    "workspaceSymbolProvider",
  }) do
    check("strip removes " .. name, not caps[name], vim.inspect(caps[name]))
  end
  check("strip keeps codeActionProvider", caps.codeActionProvider == code_actions, vim.inspect(caps.codeActionProvider))
  check("strip keeps executeCommandProvider", caps.executeCommandProvider ~= nil)
  check("strip keeps textDocumentSync", caps.textDocumentSync == 2, caps.textDocumentSync)
  check("strip tolerates nil", lsp_util.strip_pylsp_capabilities(nil) == nil)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
