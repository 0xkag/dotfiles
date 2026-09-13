return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { "<C-\\>", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Toggle terminal" },
    { "<leader>ot", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Terminal" },
    {
      "<leader>of",
      function()
        vim.cmd("2ToggleTerm direction=float")
      end,
      desc = "Float terminal",
    },
  },
  opts = {
    direction = "horizontal",
    float_opts = {
      border = "rounded",
    },
    open_mapping = [[<c-\>]],
    persist_mode = true,
    persist_size = true,
    shade_terminals = false,
    size = 15,
    start_in_insert = true,
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = function(event)
        local map = require("config.code_mode.shared").buf_map(event.buf)

        map("t", "<Esc>", [[<C-\><C-n>]], "Terminal normal mode")
        map("t", "<C-h>", [[<Cmd>wincmd h<CR>]], "Window left")
        map("t", "<C-j>", [[<Cmd>wincmd j<CR>]], "Window down")
        map("t", "<C-k>", [[<Cmd>wincmd k<CR>]], "Window up")
        map("t", "<C-l>", [[<Cmd>wincmd l<CR>]], "Window right")
        map("t", "<C-w>", [[<C-\><C-n><C-w>]], "Window command")
      end,
    })
  end,
}
