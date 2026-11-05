-- c/cpp는 프로젝트에 .clang-format이 있을 때만 포맷한다.
-- 포맷 규칙이 없는 기존 코드가 저장할 때마다 통째로 재정렬되는 것을 막기 위해서다.
local no_lsp_fallback = { c = true, cpp = true }

return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      desc = "Format buffer",
    },
  },
  opts = {
    -- .clang-format이 없는 c/cpp를 저장할 때마다 경고가 뜨지 않게 한다
    notify_no_formatters = false,
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_organize_imports", "ruff_format" },
      rust = { "rustfmt" },
      c = { "clang-format" },
      cpp = { "clang-format" },
    },
    formatters = {
      ["clang-format"] = {
        condition = function(_, ctx)
          return vim.fs.find({ ".clang-format", "_clang-format" }, { path = ctx.dirname, upward = true })[1] ~= nil
        end,
      },
    },
    format_on_save = function(buf)
      return { timeout_ms = 1000, lsp_format = no_lsp_fallback[vim.bo[buf].filetype] and "never" or "fallback" }
    end,
  },
}
