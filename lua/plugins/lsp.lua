-- 언어 서버 설정은 Neovim 내장 vim.lsp.config/enable을 사용한다.
-- nvim-lspconfig는 lsp/*.lua 기본값을, mason은 바이너리를 제공한다.
local servers = {
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      },
    },
  },
  pyright = {},
  ruff = {},
  rust_analyzer = {},
  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--header-insertion=never",
      -- compile_commands.json의 gcc/clang에게 시스템 include 경로를 물어보도록 허용한다
      "--query-driver=**/*gcc*,**/*g++*,**/*clang*",
    },
  },
}

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "Mason", "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate" },
  dependencies = {
    "mason-org/mason.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    require("mason").setup()

    -- mason 패키지 이름. clangd는 시스템에 없을 때만 mason으로 받는다.
    -- PATH 탐색 비용이 시작 시간에 더해지지 않도록 spec 평가 시점이 아니라 여기서 확인한다.
    local tools = { "lua-language-server", "pyright", "ruff", "rust-analyzer", "stylua" }
    if vim.fn.executable("clangd") == 0 then
      table.insert(tools, "clangd")
    end
    -- 데몬 시작이 네트워크에 묶이지 않도록 설치는 scripts/install.ps1이나 수동 명령으로만 한다
    require("mason-tool-installer").setup({ ensure_installed = tools, run_on_start = false })

    vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
    for name, config in pairs(servers) do
      vim.lsp.config(name, config)
      vim.lsp.enable(name)
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("plugin_lsp", { clear = true }),
      callback = function(args)
        local function map(lhs, rhs, desc, opts)
          local o = vim.tbl_extend("force", { buffer = args.buf, desc = desc }, opts or {})
          vim.keymap.set("n", lhs, rhs, o)
        end
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        -- 내장 grn/gra 등과 접두사가 겹쳐 timeoutlen만큼 기다리지 않도록 nowait로 둔다
        map("gr", vim.lsp.buf.references, "Find references", { nowait = true })
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")
      end,
    })
  end,
}
