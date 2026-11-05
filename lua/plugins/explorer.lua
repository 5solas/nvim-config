return {
  "stevearc/oil.nvim",
  cmd = "Oil",
  keys = {
    { "-", "<Cmd>Oil<CR>", desc = "Open parent directory" },
  },
  init = function()
    -- 디렉터리를 인자로 시작하면(nvim .) oil이 netrw 대신 열리도록 미리 로드한다
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      require("lazy").load({ plugins = { "oil.nvim" } })
    end
  end,
  opts = {},
}
