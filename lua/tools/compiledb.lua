-- SCons를 빌드하지 않고 `scons -n` 출력을 compiledb로 파싱해 compile_commands.json을 만든다.
--
-- compiledb를 그대로 쓸 수 없어 보정하는 부분 (compiledb 0.10.7, SCons 4.11에서 확인):
--   1. 빌드 후에는 scons -n이 "up to date"만 출력한다.
--      -> .sconsign*을 잠시 치워 전체 명령을 출력시키고 바로 복원한다.
--   2. compiledb의 컴파일러 정규식은 gcc.exe에 매칭되지 않고 unescape()는 src\foo.c의 \f를
--      폼피드로 바꾼다. 그 결과 Windows 로그에서는 항목이 0개가 된다.
--      -> 파싱 전에 로그의 \를 /로 바꾸고 .exe를 뗀다.
--   3. unescape()가 인자의 UTF-8 한글을 깨뜨린다.
--      -> 파싱 후 latin1 해석을 되돌린다.
local M = {}

local BAK = ".compiledb-bak"
local running = false

local function notify(msg, level)
  vim.schedule(function()
    vim.notify("CompileDb: " .. msg, level or vim.log.levels.INFO)
  end)
end

---scons -n 출력을 compiledb가 파싱할 수 있는 형태로 바꾼다.
---@param log string
---@return string
function M.normalize_log(log)
  local lines = {}
  for line in vim.gsplit(log, "\r?\n") do
    -- 이스케이프된 따옴표(-DNAME=\"x\")는 유지하고 나머지 \는 경로 구분자로 본다
    line = line:gsub('\\(.?)', function(next_char)
      return next_char == '"' and '\\"' or "/" .. next_char
    end)
    line = line:gsub('%.[eE][xX][eE]("?%s)', "%1")
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

---compiledb가 latin1로 잘못 해석한 UTF-8 문자열을 되돌린다.
---@param s string
---@return string
function M.fix_mojibake(s)
  if not s:find("[\128-\255]") then
    return s
  end
  local bytes = vim.iconv(s, "utf-8", "latin1")
  return bytes and bytes ~= "" and bytes or s
end

---@param root string
---@return string[] paths 루트의 .sconsign* 파일
local function sconsign_files(root)
  local paths = {}
  for name, kind in vim.fs.dir(root) do
    if kind == "file" and vim.startswith(name, ".sconsign") then
      paths[#paths + 1] = vim.fs.joinpath(root, name)
    end
  end
  return paths
end

---@param root string
---@return string[] moved
local function hide_sconsign(root)
  -- 이전 실행이 강제 종료되어 남은 백업이 있으면 그것이 진짜 빌드 상태다
  for _, path in ipairs(sconsign_files(root)) do
    if vim.endswith(path, BAK) then
      vim.uv.fs_rename(path, path:sub(1, -#BAK - 1))
    end
  end
  local moved = {}
  for _, path in ipairs(sconsign_files(root)) do
    if vim.uv.fs_rename(path, path .. BAK) then
      moved[#moved + 1] = path
    end
  end
  return moved
end

---scons -n이 만든 빈 파일을 지우고 원래 파일을 되돌린다.
---@param root string
---@param moved string[]
local function restore_sconsign(root, moved)
  for _, path in ipairs(sconsign_files(root)) do
    if not vim.endswith(path, BAK) then
      vim.uv.fs_unlink(path)
    end
  end
  for _, path in ipairs(moved) do
    vim.uv.fs_rename(path .. BAK, path)
  end
end

---@param log string
---@return string
local function empty_hint(log)
  if log:find("is up to date", 1, true) then
    return "no compile commands: SCons says up to date, so its signature file is outside the project root "
      .. "(custom SConsignFile?). Delete it, or use env.Tool('compilation_db') in the SConstruct."
  end
  if log:find("%f[%w]cl%f[%W]") or log:find("%f[%w]cl%.exe") then
    return "no compile commands: compiledb cannot parse MSVC cl. "
      .. "Use env.Tool('compilation_db') and env.CompilationDatabase() in the SConstruct."
  end
  return "no compile commands found in the scons -n output."
end

---@param path string
---@param entries table[]
local function write_atomic(path, entries)
  local tmp = path .. ".tmp"
  local fd = assert(io.open(tmp, "wb"))
  fd:write(vim.json.encode(entries), "\n")
  fd:close()
  assert(vim.uv.fs_rename(tmp, path))
end

---@param args string[]? scons에 그대로 넘길 인자
---@param on_done? fun(ok: boolean, count: integer)
function M.generate(args, on_done)
  local function finish(ok, count)
    running = false
    if on_done then
      vim.schedule(function()
        on_done(ok, count or 0)
      end)
    end
  end

  if running then
    notify("already running", vim.log.levels.WARN)
    return
  end

  local root = vim.fs.root(0, { "SConstruct", "Sconstruct", "sconstruct" })
  if not root then
    notify("no SConstruct found upward from the current buffer", vim.log.levels.ERROR)
    return finish(false)
  end
  local scons = vim.g.compiledb_scons or vim.fn.exepath("scons")
  local compiledb = vim.g.compiledb_bin or vim.fn.exepath("compiledb")
  if scons == "" or compiledb == "" then
    notify("scons and compiledb must be on PATH (uv tool install scons compiledb)", vim.log.levels.ERROR)
    return finish(false)
  end

  running = true
  local moved = hide_sconsign(root)
  local cmd = vim.list_extend({ scons, "-n", "-Q" }, args or {})
  notify("running " .. table.concat(cmd, " ", 2) .. " in " .. root)

  vim.system(cmd, { cwd = root, text = true, env = { PYTHONIOENCODING = "utf-8" }, timeout = 300000 }, function(res)
    vim.schedule(function()
      restore_sconsign(root, moved)

      if res.code ~= 0 then
        notify("scons failed (" .. res.code .. "):\n" .. (res.stderr or ""), vim.log.levels.ERROR)
        return finish(false)
      end

      local log = res.stdout or ""
      vim.system(
        -- -S: 생성될 소스 파일은 드라이런 시점에 아직 없을 수 있다
        { compiledb, "-S", "-o", "-" },
        { cwd = root, text = true, stdin = M.normalize_log(log), env = { PYTHONUTF8 = "1" } },
        function(db)
          vim.schedule(function()
            if db.code ~= 0 then
              notify("compiledb failed:\n" .. (db.stderr or ""), vim.log.levels.ERROR)
              return finish(false)
            end
            local ok, entries = pcall(vim.json.decode, db.stdout or "")
            if not ok or type(entries) ~= "table" then
              notify("compiledb returned invalid JSON", vim.log.levels.ERROR)
              return finish(false)
            end
            if #entries == 0 then
              notify(empty_hint(log), vim.log.levels.WARN)
              return finish(false, 0)
            end

            for _, entry in ipairs(entries) do
              entry.arguments = vim.tbl_map(M.fix_mojibake, entry.arguments)
            end
            write_atomic(vim.fs.joinpath(root, "compile_commands.json"), entries)

            if #vim.lsp.get_clients({ name = "clangd" }) > 0 then
              vim.cmd("lsp restart clangd")
            end
            notify(("compile_commands.json: %d entries"):format(#entries))
            finish(true, #entries)
          end)
        end
      )
    end)
  end)
end

return M
