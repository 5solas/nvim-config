-- :CompileDb 등록만 한다. 구현은 lua/tools/compiledb.lua에 있고 호출할 때 로드한다.
vim.api.nvim_create_user_command("CompileDb", function(opts)
  require("tools.compiledb").generate(opts.fargs)
end, { nargs = "*", desc = "Generate compile_commands.json from a scons -n dry run" })

-- scons -n은 SConstruct(Python)를 실행하므로 자동 실행하지 않고 안내만 한다.
local hinted = {}
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("plugin_compiledb", { clear = true }),
  pattern = { "c", "cpp" },
  callback = function(args)
    local root = vim.fs.root(args.buf, { "SConstruct", "Sconstruct", "sconstruct" })
    if root and not hinted[root] and not vim.uv.fs_stat(vim.fs.joinpath(root, "compile_commands.json")) then
      hinted[root] = true
      vim.notify("SCons project without compile_commands.json. Run :CompileDb", vim.log.levels.INFO)
    end
  end,
})
