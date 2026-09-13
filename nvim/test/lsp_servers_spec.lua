-- Headless test for config.lsp_servers: the language servers as data.
-- Run: nvim/test/run.sh lsp_servers
--
-- The table used to live inside plugins/lsp.lua's 885-line config closure,
-- where no spec could load it. It holds only what differs from each server's
-- defaults; capabilities and the file-watch guard are added when the servers
-- are enabled, so no entry carries them here.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_servers_spec.lua$", "")
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

vim.notify = function() end

local ok, lsp_servers = pcall(require, "config.lsp_servers")
check("config.lsp_servers loads", ok, lsp_servers)
if not ok then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
end
local servers = lsp_servers.servers

-- The shape: one table per name, names sorted for vim.lsp.enable, nothing
-- shared by every server repeated per server.
do
  local names = lsp_servers.names()
  local sorted = vim.deepcopy(names)
  table.sort(sorted)
  check("names() is sorted", vim.deep_equal(names, sorted), vim.inspect(names))
  check("names() covers the table", #names == vim.tbl_count(servers) and #names > 10, #names .. " vs " .. vim.tbl_count(servers))
  for _, name in ipairs(names) do
    check(name .. " is a table", type(servers[name]) == "table", type(servers[name]))
    check(name .. " carries no capabilities of its own", servers[name].capabilities == nil, vim.inspect(servers[name].capabilities))
  end
  for _, expected in ipairs({ "bashls", "lua_ls", "pylsp", "pyright", "ruff", "terraformls", "yamlls" }) do
    check(expected .. " is configured", servers[expected] ~= nil)
  end
end

-- pylsp: its cmd resolves per root when the client starts, and on_init strips
-- the capabilities pyright and ruff own, leaving rope's code actions.
do
  check("pylsp cmd is resolved lazily", type(servers.pylsp.cmd) == "function", type(servers.pylsp.cmd))
  local client = {
    server_capabilities = {
      codeActionProvider = true,
      completionProvider = { triggerCharacters = { "." } },
      hoverProvider = true,
      renameProvider = true,
    },
  }
  servers.pylsp.on_init(client)
  check("pylsp on_init strips rename", not client.server_capabilities.renameProvider, vim.inspect(client.server_capabilities))
  check("pylsp on_init strips hover and completion", not client.server_capabilities.hoverProvider and not client.server_capabilities.completionProvider, vim.inspect(client.server_capabilities))
  check("pylsp on_init keeps code actions", client.server_capabilities.codeActionProvider == true, vim.inspect(client.server_capabilities))
  check("pylsp disables the plugins other servers cover", servers.pylsp.settings.pylsp.plugins.jedi_completion.enabled == false and servers.pylsp.settings.pylsp.plugins.pylsp_rope.enabled == true, vim.inspect(servers.pylsp.settings.pylsp.plugins))
end

-- pyright: the interpreter follows the root at before_init, and the buffer
-- command to repoint it is created on attach.
do
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local new_config = { root_dir = root, settings = { python = { analysis = { typeCheckingMode = "basic" } } } }
  servers.pyright.before_init(nil, new_config)
  check("pyright before_init keeps the existing settings", new_config.settings.python.analysis.typeCheckingMode == "basic", vim.inspect(new_config.settings))
  check("and adds the resolved interpreter settings", new_config.settings.python.analysis.diagnosticMode == "openFilesOnly", vim.inspect(new_config.settings))
  check("pyright settings are present at load too", type(servers.pyright.settings) == "table" and servers.pyright.settings.python ~= nil, vim.inspect(servers.pyright.settings))

  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  local notified = {}
  local client = {
    settings = {},
    notify = function(_, method, params)
      table.insert(notified, { method = method, params = params })
    end,
  }
  servers.pyright.on_attach(client, buf)
  local commands = vim.api.nvim_buf_get_commands(buf, {})
  check("pyright on_attach adds LspPyrightSetPythonPath", commands.LspPyrightSetPythonPath ~= nil, vim.inspect(vim.tbl_keys(commands)))
  vim.cmd("LspPyrightSetPythonPath /opt/py/bin/python")
  check("the command repoints the interpreter", client.settings.python and client.settings.python.pythonPath == "/opt/py/bin/python", vim.inspect(client.settings))
  check("and tells the server", #notified == 1 and notified[1].method == "workspace/didChangeConfiguration", vim.inspect(notified))
  vim.fn.delete(root, "rf")
end

-- The smaller entries that carry a decision.
do
  check("lua_ls indexes the runtime and luv types only", vim.deep_equal(servers.lua_ls.settings.Lua.workspace.library, { vim.env.VIMRUNTIME, "${3rd}/luv/library" }), vim.inspect(servers.lua_ls.settings.Lua.workspace.library))
  check("lua_ls knows the vim global", vim.deep_equal(servers.lua_ls.settings.Lua.diagnostics.globals, { "vim" }))
  check("terraform-ls serves tftpl too", vim.list_contains(servers.terraformls.filetypes, "tftpl"), vim.inspect(servers.terraformls.filetypes))
  check("terraform-ls ignores the single-file warning", servers.terraformls.init_options.ignoreSingleFileWarning == true)
  check("yaml-ls does not enforce key order", servers.yamlls.settings.yaml.keyOrdering == false)
  check("rust-analyzer checks all features", servers.rust_analyzer.settings["rust-analyzer"].cargo.allFeatures == true)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
