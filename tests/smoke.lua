-- 실제 scons, compiledb, gcc, clangd로 돌리는 통합 테스트. 실행 방법:
--   nvim --headless -c "luafile tests/smoke.lua"
local db = require("tools.compiledb")
local failures = 0

local function check(name, ok, detail)
  print(("%s %s%s"):format(ok and "ok  " or "FAIL", name, (not ok and detail) and (" -- " .. tostring(detail)) or ""))
  if not ok then
    failures = failures + 1
  end
end

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function project(dirname, sconstruct)
  local root = vim.fs.normalize(vim.fn.tempname()) .. "/" .. dirname
  write(root .. "/inc/a.h", "#define V 1\n")
  write(root .. "/src/main.c", '#include <stdio.h>\n#include "a.h"\nint main(void) { printf("%d", V); return 0; }\n')
  write(root .. "/src/util.c", "int f(void) { return 2; }\n")
  write(root .. "/SConstruct", sconstruct)
  return root
end

local MINGW = [[
import os
env = Environment(tools=['mingw'], ENV=os.environ.copy(), CPPPATH=['inc'], CPPDEFINES=[('NAME', '\\"x\\"')])
env.Program('app', ['src/main.c', 'src/util.c'])
]]

---@return boolean ok, integer count
local function generate(root, args)
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.cmd("enew!")
  local done, ok, count = false, false, 0
  db.generate(args, function(o, c)
    done, ok, count = true, o, c
  end)
  vim.wait(120000, function()
    return done
  end, 20)
  return ok, count
end

local function scons(root)
  return vim.system({ "scons", "-Q" }, { cwd = root, text = true }):wait()
end

local function entries(root)
  return vim.json.decode(read(root .. "/compile_commands.json") or "[]")
end

-- 순수 함수
check("normalize: path separators", db.normalize_log([[gcc -c src\foo.c]]) == "gcc -c src/foo.c")
check("normalize: escaped quote kept", db.normalize_log([[gcc -DN=\"x\" a.c]]) == [[gcc -DN=\"x\" a.c]])
check("normalize: bare .exe", db.normalize_log([[C:\m\gcc.exe -c a.c]]) == "C:/m/gcc -c a.c")
check(
  "normalize: quoted .exe",
  db.normalize_log([["C:\P F\gcc.exe" -c a.c]]) == '"C:/P F/gcc" -c a.c',
  db.normalize_log([["C:\P F\gcc.exe" -c a.c]])
)
check("normalize: CRLF", db.normalize_log("a\r\nb") == "a\nb")
check("mojibake: ascii unchanged", db.fix_mojibake("-Iinc") == "-Iinc")
check("mojibake: reversed", db.fix_mojibake(vim.iconv("-I한글", "latin1", "utf-8")) == "-I한글")

-- 빌드된 프로젝트: 전체 항목이 나오고 빌드 상태가 그대로여야 한다
do
  local root = project("built", MINGW)
  local built = scons(root)
  check("scons build", built.code == 0, built.stderr)
  local sign = read(root .. "/.sconsign.dblite")
  local mtime = vim.uv.fs_stat(root .. "/src/main.o").mtime.nsec
  local up = vim.system({ "scons", "-n", "-Q" }, { cwd = root, text = true }):wait()
  check("plain scons -n prints no compile lines", not up.stdout:find("gcc", 1, true), up.stdout)

  local ok, count = generate(root)
  check("built project: two entries", ok and count == 2, count)
  local e = entries(root)
  check("arguments use /", e[1] and vim.tbl_contains(e[1].arguments, "src/main.c"), vim.inspect(e[1]))
  check("define survives", e[1] and vim.tbl_contains(e[1].arguments, '-DNAME="x"'), vim.inspect(e[1]))
  check("sconsign restored byte for byte", read(root .. "/.sconsign.dblite") == sign)
  check("no backup left", read(root .. "/.sconsign.dblite.compiledb-bak") == nil)
  check("objects untouched", vim.uv.fs_stat(root .. "/src/main.o").mtime.nsec == mtime)
  local again = scons(root)
  check("next real build is a no-op", again.stdout:find("up to date", 1, true) ~= nil, again.stdout)
end

-- 한글과 공백이 있는 경로
do
  local root = project(
    "한글 경로",
    "import os\nenv = Environment(tools=['mingw'], ENV=os.environ.copy(), "
      -- 프로젝트 내부 경로는 SCons가 상대경로로 줄이므로 외부 경로를 쓴다
      .. "CCFLAGS=['-IC:/외부 경로/한글/inc'])\nenv.Program('app', ['src/main.c'])\n"
  )
  local ok, count = generate(root)
  check("korean path: one entry", ok and count == 1, count)
  local e = entries(root)[1] or { arguments = {} }
  local joined = table.concat(e.arguments, " ")
  check("korean path: arguments readable", joined:find("C:/외부 경로/한글/inc", 1, true) ~= nil, joined)
  check("korean path: directory readable", (e.directory or ""):find("한글 경로", 1, true) ~= nil, e.directory)
end

-- VariantDir: duplicate=1(SCons 기본값)이면 file이 복사본(build/main.c)을 가리킨다.
-- 이때 원본을 열면 clangd가 가장 가까운 항목의 플래그를 빌려 쓴다.
do
  for _, duplicate in ipairs({ 0, 1 }) do
    local root = project(
      "variant" .. duplicate,
      "import os\nenv = Environment(tools=['mingw'], ENV=os.environ.copy(), CPPPATH=['#inc'])\n"
        .. ("VariantDir('build', 'src', duplicate=%d)\n"):format(duplicate)
        .. "env.Program('app', ['build/main.c', 'build/util.c'])\n"
    )
    local ok, count = generate(root)
    local e = entries(root)[1] or {}
    check(("variantdir duplicate=%d: entries"):format(duplicate), ok and count == 2, count)
    check(
      ("variantdir duplicate=%d: file"):format(duplicate),
      e.file == (duplicate == 1 and "build/main.c" or "src/main.c"),
      e.file
    )

    -- -Iinc가 적용되어야만 a.h 오류가 사라진다. 빈 진단 발행까지 기다려야 판정할 수 있다.
    local published = false
    local id = vim.api.nvim_create_autocmd("DiagnosticChanged", {
      callback = function()
        published = true
      end,
    })
    vim.cmd.edit("src/main.c")
    local buf = vim.api.nvim_get_current_buf()
    local got = vim.wait(30000, function()
      return published and #vim.lsp.get_clients({ bufnr = buf, name = "clangd" }) > 0
    end, 50)
    vim.api.nvim_del_autocmd(id)
    local errs = vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
    check(
      ("variantdir duplicate=%d: clangd resolves the original source"):format(duplicate),
      got and #errs == 0,
      vim.inspect(vim.tbl_map(function(d)
        return d.message
      end, errs))
    )
    for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
      client:stop(true)
    end
    vim.wait(2000, function()
      return #vim.lsp.get_clients({ name = "clangd" }) == 0
    end, 50)
  end
end

-- 강제 종료 후 남은 백업 복구
do
  local root = project("recover", MINGW)
  scons(root)
  local sign = read(root .. "/.sconsign.dblite")
  vim.uv.fs_rename(root .. "/.sconsign.dblite", root .. "/.sconsign.dblite.compiledb-bak")
  write(root .. "/.sconsign.dblite", "")
  local ok = generate(root)
  check("recover: generated", ok)
  check("recover: original state restored", read(root .. "/.sconsign.dblite") == sign)
end

-- 실패 경로
do
  local root = project("broken", MINGW)
  scons(root)
  local sign = read(root .. "/.sconsign.dblite")
  write(root .. "/compile_commands.json", "[]")
  write(root .. "/SConstruct", "this is not python\n")
  local ok = generate(root)
  check("scons failure reports failure", ok == false)
  check("scons failure restores state", read(root .. "/.sconsign.dblite") == sign)
  check("scons failure keeps old database", read(root .. "/compile_commands.json") == "[]")
end

do
  local root = project("msvc", "env = Environment(tools=[])\nenv.Command('a.obj', 'src/util.c', 'cl /c /nologo $SOURCE')\n")
  local shown
  local notify = vim.notify
  vim.notify = function(msg)
    shown = msg
  end
  local ok, count = generate(root)
  vim.wait(50)
  vim.notify = notify
  check("msvc: no database and a clear hint", not ok and count == 0 and (shown or ""):find("MSVC", 1, true) ~= nil, shown)
end

-- clangd가 생성된 데이터베이스를 실제로 쓰는지 확인
do
  local root = project("clangd", MINGW)
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.cmd.edit("src/main.c")
  local buf = vim.api.nvim_get_current_buf()
  local function attached()
    return #vim.lsp.get_clients({ bufnr = buf, name = "clangd" }) > 0
  end
  local function errors()
    return vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
  end
  check("clangd attaches", vim.wait(20000, attached, 50))
  check(
    "before: a.h not found",
    vim.wait(20000, function()
      return #errors() > 0
    end, 50),
    "no error reported"
  )

  local done, count = false, 0
  db.generate(nil, function(_, c)
    done, count = true, c
  end)
  vim.wait(120000, function()
    return done
  end, 20)
  check("database generated from an open buffer", count == 2, count)
  check(
    "after: no errors, system and project headers resolve",
    vim.wait(30000, function()
      return attached() and #errors() == 0
    end, 100),
    vim.inspect(vim.tbl_map(function(d)
      return d.message
    end, errors()))
  )

  local maps = vim.api.nvim_buf_get_keymap(buf, "n")
  local gr = vim.tbl_filter(function(m)
    return m.lhs == "gr"
  end, maps)[1]
  check("gr is buffer-local and nowait", gr ~= nil and gr.nowait == 1, vim.inspect(gr))
end

-- 인코딩
do
  local path = vim.fs.normalize(vim.fn.tempname()) .. ".txt"
  write(path, vim.iconv("한글 cp949\n", "utf-8", "cp949"))
  vim.cmd.edit(vim.fn.fnameescape(path))
  check("cp949 detected", vim.bo.fileencoding == "cp949", vim.bo.fileencoding)
  check("cp949 decoded", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "한글 cp949")
end

-- 저장 시 포맷
do
  local dir = vim.fs.normalize(vim.fn.tempname())
  local ugly = "int  main( void ){return 0;}\n"
  write(dir .. "/plain/a.c", ugly)
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/plain/a.c"))
  vim.cmd.write()
  check("c without .clang-format is not reformatted", read(dir .. "/plain/a.c") == ugly, read(dir .. "/plain/a.c"))

  write(dir .. "/styled/.clang-format", "BasedOnStyle: LLVM\n")
  write(dir .. "/styled/a.c", ugly)
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/styled/a.c"))
  vim.cmd.write()
  check("c with .clang-format is formatted", read(dir .. "/styled/a.c") ~= ugly, read(dir .. "/styled/a.c"))

  write(dir .. "/a.py", "x   =  1\n")
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.py"))
  vim.cmd.write()
  check("python formatted by ruff", read(dir .. "/a.py") == "x = 1\n", read(dir .. "/a.py"))

  write(dir .. "/a.lua", "local   x  =  1\nreturn x\n")
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.lua"))
  vim.cmd.write()
  check("lua formatted by stylua", read(dir .. "/a.lua") == "local x = 1\nreturn x\n", read(dir .. "/a.lua"))
end

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
vim.cmd(failures == 0 and "qa!" or "cq!")
