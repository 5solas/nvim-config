-- 헤드리스 파이프 데몬의 서버 측 기능. 클라이언트는 bin/nv.ps1이다.
--   open()   : 클라이언트가 보낸 파일을 연다
--   status() : 데몬 상태를 JSON으로 돌려준다
--   stop()   : 데몬을 종료한다
local M = {}

---@return integer? chan 현재 붙어 있는 Neovide의 RPC 채널
local function neovide_channel()
  local chan = vim.g.neovide_channel_id
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.chan == chan then
      return chan
    end
  end
end

---창이 아직 비어 있는 탭인가
local function current_tab_is_blank()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local buf = vim.api.nvim_get_current_buf()
  return #wins == 1
    and vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

---@param req { cwd: string, paths: string[] }
local function do_open(req)
  -- 호출한 셸의 작업 폴더를 탭 단위로 반영한다. 다른 프로젝트의 탭을 건드리지 않기 위해서다.
  if vim.fs.normalize(vim.fn.getcwd()) ~= vim.fs.normalize(req.cwd) then
    if not current_tab_is_blank() then
      vim.cmd.tabnew()
    end
    vim.cmd.tcd(vim.fn.fnameescape(req.cwd))
  end
  for _, path in ipairs(req.paths) do
    vim.cmd.drop({ args = { vim.fn.fnameescape(path) } })
  end
end

---클라이언트 요청 처리. RPC 호출을 막지 않도록 실제 작업은 뒤로 미룬다.
---스왑 파일 대화상자 같은 입력 대기는 답할 UI가 있을 때 열려야 하므로 UI가 없으면 UIEnter까지 기다린다.
---@param json string
---@return string neovide "1"이면 이미 Neovide가 붙어 있다
function M.open(json)
  local req = vim.json.decode(json)
  local chan = neovide_channel()
  if #vim.api.nvim_list_uis() > 0 then
    vim.schedule(function()
      do_open(req)
    end)
  else
    vim.api.nvim_create_autocmd("UIEnter", {
      once = true,
      callback = vim.schedule_wrap(function()
        do_open(req)
      end),
    })
  end
  if chan then
    vim.rpcnotify(chan, "neovide.focus_window")
    return "1"
  end
  return "0"
end

---@return string json
function M.status()
  local modified = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      modified[#modified + 1] = name ~= "" and name or ("[No Name] #" .. buf)
    end
  end
  return vim.json.encode({
    pid = vim.fn.getpid(),
    address = vim.v.servername,
    uis = #vim.api.nvim_list_uis(),
    neovide = neovide_channel() ~= nil,
    buffers = #vim.fn.getbufinfo({ buflisted = 1 }),
    modified = modified,
    cwd = vim.fn.getcwd(),
    lsp = vim.tbl_map(function(c)
      return c.name
    end, vim.lsp.get_clients()),
  })
end

---응답을 보낸 뒤 종료한다. 수정된 버퍼 검사는 클라이언트가 status()로 먼저 한다.
---@return string
function M.stop()
  vim.defer_fn(function()
    vim.cmd("qa!")
  end, 10)
  return "stopping"
end

-- 아래부터는 데몬으로 실행될 때만 동작한다.
if vim.g.nvim_daemon then
  -- 마지막 창의 :q, :wq, ZZ, ZQ는 데몬을 끝내지 않고 UI만 분리한다. :qa는 그대로 종료한다.
  -- QuitPre에서 창을 하나 더 만들면 :q는 원래 창만 닫고 끝난다.
  vim.api.nvim_create_autocmd("QuitPre", {
    group = vim.api.nvim_create_augroup("core_daemon", { clear = true }),
    callback = function()
      if #vim.api.nvim_list_uis() == 0 then
        return
      end
      local normal = vim.tbl_filter(function(win)
        return vim.api.nvim_win_get_config(win).relative == ""
      end, vim.api.nvim_list_wins())
      if #normal == 1 then
        vim.cmd.new()
        -- :q 직후의 :detach는 서버를 멈추게 하므로(0.12.6, Windows) UI 채널을 직접 닫는다
        vim.schedule(function()
          -- 수정된 버퍼의 :qa는 저장 여부를 묻는다. 지금 분리하면 답할 UI가 사라진다.
          if vim.api.nvim_get_mode().mode:sub(1, 1) == "r" then
            return
          end
          for _, ui in ipairs(vim.api.nvim_list_uis()) do
            pcall(vim.fn.chanclose, ui.chan)
          end
        end)
      end
    end,
  })

  -- 지연 로드되는 플러그인을 미리 읽어 첫 파일이 바로 열리게 한다
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.schedule(function()
        local lazy = require("lazy")
        local names = {}
        for _, plugin in ipairs(lazy.plugins()) do
          if not plugin._.loaded then
            names[#names + 1] = plugin.name
          end
        end
        lazy.load({ plugins = names })
      end)
    end,
  })
end

return M
