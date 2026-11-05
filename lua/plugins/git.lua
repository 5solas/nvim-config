return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  keys = {
    { "]h", "<Cmd>Gitsigns next_hunk<CR>", desc = "Next git hunk" },
    { "[h", "<Cmd>Gitsigns prev_hunk<CR>", desc = "Previous git hunk" },
    { "<leader>gs", "<Cmd>Gitsigns stage_hunk<CR>", mode = { "n", "x" }, desc = "Stage hunk" },
    { "<leader>gr", "<Cmd>Gitsigns reset_hunk<CR>", mode = { "n", "x" }, desc = "Reset hunk" },
    { "<leader>gp", "<Cmd>Gitsigns preview_hunk_inline<CR>", desc = "Preview hunk inline" },
    { "<leader>gb", "<Cmd>Gitsigns blame_line<CR>", desc = "Blame line" },
    { "<leader>gd", "<Cmd>Gitsigns diffthis<CR>", desc = "Diff this file" },
  },
  opts = {},
}
