-- 데몬에 Lua 코드를 보내고 반환값을 표준 출력에 쓴다.
--   nvim -l nvd-rpc.lua <pipe> <lua code> [arg]
-- nvim --remote-expr는 출력을 캡처하면 결과 대신 TUI 제어문자만 나와서(0.12.6, Windows) 직접 호출한다.
local pipe, code, value = arg[1], arg[2], arg[3]

-- 데몬이 스왑 파일 대화상자 같은 입력을 기다리면 RPC는 응답하지 않는다. 멈추는 대신 종료 코드 3으로 알린다.
local EXIT_BUSY = 3
local TIMEOUT_MS = 5000
vim.uv.new_timer():start(TIMEOUT_MS, 0, function()
  os.exit(EXIT_BUSY)
end)

local chan = vim.fn.sockconnect("pipe", pipe, { rpc = true })
local result = vim.rpcrequest(chan, "nvim_exec_lua", code, { value })
if result ~= nil and result ~= vim.NIL then
  io.stdout:write(type(result) == "string" and result or vim.json.encode(result))
end
