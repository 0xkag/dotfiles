-- The language servers this config enables, as data: one entry per
-- vim.lsp.config name, holding only what differs from the server's defaults.
-- Capabilities and the file-watch guard are shared by every server and are
-- added where the servers are enabled (plugins/lsp.lua), so no entry carries
-- them; that is what keeps this table loadable by a spec.
local M = {}

local lsp_util = require("config.lsp_util")
local python_env = require("config.python")

local function refresh_pyright_config(new_config, root_dir)
  new_config.settings = vim.tbl_deep_extend(
    "force",
    new_config.settings or {},
    python_env.pyright_settings(root_dir)
  )
end

M.servers = {
  ansiblels = {},
  bashls = {},
  clangd = {},
  cssls = {},
  dockerls = {},
  gopls = {},
  html = {},
  jdtls = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          checkThirdParty = false,
          -- The runtime and libuv types only. nvim_get_runtime_file("",
          -- true) handed lua_ls every plugin directory to index on each
          -- start; lazydev.nvim is the on-demand way back to plugin types.
          library = {
            vim.env.VIMRUNTIME,
            "${3rd}/luv/library",
          },
        },
      },
    },
  },
  marksman = {},
  pylsp = {
    -- Resolved per root when the client starts, so a project venv's pylsp
    -- wins over the pipx one (see python_env.pylsp_cmd).
    cmd = lsp_util.lazy_cmd(python_env.pylsp_cmd),
    -- pylsp advertises capabilities for every plugin even when disabled via
    -- settings. Strip the ones pyright/ruff own so other clients win rename,
    -- hover, definitions, etc. (see lsp_util.strip_pylsp_capabilities). This
    -- has to be on_init, not on_attach: the runtime fires LspAttach before
    -- on_attach, so a strip there ran after every LspAttach handler had
    -- already read the full set, and it ran again for each buffer.
    on_init = function(client)
      lsp_util.strip_pylsp_capabilities(client.server_capabilities)
    end,
    settings = {
      pylsp = {
        plugins = {
          pyflakes = { enabled = false },
          pycodestyle = { enabled = false },
          mccabe = { enabled = false },
          pylint = { enabled = false },
          flake8 = { enabled = false },
          jedi_completion = { enabled = false },
          jedi_hover = { enabled = false },
          jedi_signature_help = { enabled = false },
          jedi_definition = { enabled = false },
          jedi_references = { enabled = false },
          jedi_symbols = { enabled = false },
          jedi_rename = { enabled = false },
          rope_rename = { enabled = false },
          pylsp_rope = { enabled = true, rename = false },
          rope_autoimport = { enabled = false },
        },
      },
    },
  },
  pyright = {
    before_init = function(_, new_config)
      refresh_pyright_config(new_config, new_config.root_dir)
    end,
    on_attach = function(client, bufnr)
      vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", function(command)
        local path = command.args
        client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
          python = { pythonPath = path },
        })
        client:notify("workspace/didChangeConfiguration", {
          settings = client.settings,
        })
      end, {
        complete = "file",
        desc = "Reconfigure pyright with the provided python path",
        nargs = 1,
      })
    end,
    settings = python_env.pyright_settings(),
  },
  ruff = {},
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
        },
      },
    },
  },
  taplo = {},
  terraformls = {
    cmd = { "terraform-ls", "serve" },
    filetypes = { "terraform", "terraform-vars", "tftpl" },
    init_options = {
      ignoreSingleFileWarning = true,
    },
  },
  ts_ls = {},
  yamlls = {
    settings = {
      yaml = {
        keyOrdering = false,
      },
    },
  },
}

-- The server names, sorted, for vim.lsp.enable.
function M.names()
  local names = vim.tbl_keys(M.servers)
  table.sort(names)
  return names
end

return M
