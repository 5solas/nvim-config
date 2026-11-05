return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  keys = {
    { "<leader>ff", "<Cmd>FzfLua files<CR>", desc = "Find files" },
    { "<leader>fg", "<Cmd>FzfLua live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<Cmd>FzfLua buffers<CR>", desc = "Find buffers" },
    { "<leader>fr", "<Cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
    { "<leader>fh", "<Cmd>FzfLua helptags<CR>", desc = "Help tags" },
    { "<leader>fd", "<Cmd>FzfLua diagnostics_document<CR>", desc = "Document diagnostics" },
    { "<leader>f.", "<Cmd>FzfLua resume<CR>", desc = "Resume last search" },
  },
  opts = {},
}
