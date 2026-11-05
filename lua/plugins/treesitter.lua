-- nvim-treesitter main 브랜치. master와 호환되지 않는 재작성판이며 지연 로드를 지원하지 않는다.
-- 파서 빌드에 tree-sitter CLI(npm 판 제외)와 C 컴파일러가 필요하다. scripts/install.ps1이 확인한다.
local parsers = {
  "bash",
  "c",
  "cpp",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "powershell",
  "python",
  "query",
  "rust",
  "toml",
  "vim",
  "vimdoc",
  "yaml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  version = false,
  lazy = false,
  build = function()
    local ts = require("nvim-treesitter")
    ts.install(parsers):wait(600000)
    ts.update():wait(600000)
  end,
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("plugin_treesitter", { clear = true }),
      desc = "Start treesitter for buffers whose parser is installed",
      callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
