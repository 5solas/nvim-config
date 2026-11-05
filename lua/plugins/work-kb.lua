-- work-kb: Markdown 지식 베이스와 Jira 앞단. 코드는 다른 저장소(github.com/5solas/work-kb, nvim 브랜치)에 있고,
-- 그 저장소의 install.ps1이 사용자 환경 변수 WORK_KB_ROOT에 클론 위치를 적는다. 플러그인은 <WORK_KB_ROOT>\nvim이다.
-- 변수가 없거나 플러그인이 없으면 빈 spec을 돌려준다: 명령, 키, 메시지가 하나도 생기지 않는다.
-- 이 부분은 시작할 때마다 실행되므로 vim.env 읽기 한 번과 fs_stat 한 번만 한다.
-- 로컬 dir 플러그인이라 lazy-lock.json에 들어가지 않는다.
local env = vim.env.WORK_KB_ROOT
if not env or env == "" then
  return {}
end
local root = vim.fs.normalize(env)
local dir = root .. "/nvim"
if not vim.uv.fs_stat(dir .. "/lua/work-kb/init.lua") then
  return {}
end

-- 키는 플러그인의 setup()이 이 접두 키 아래에 직접 만든다. 아래 keys에는 rhs가 없어서 lazy는 누르면
-- 플러그인을 불러오는 자리 표시만 두고, 불러올 때 지운 뒤 같은 키를 다시 넣는다 (그 사이 setup이 실제 키를 만든다).
-- desc는 setup이 붙이는 것과 같은 문구다. 목록은 플러그인의 require("work-kb").keys, visual_keys와 같다.
local prefix = "<leader>k"
local function key(suffix, name, mode)
  return { prefix .. suffix, mode = mode, desc = "work-kb: " .. name }
end

return {
  dir = dir,
  name = "work-kb",
  main = "work-kb",
  cmd = "WorkKb",
  keys = {
    key("c", "capture"),
    key("C", "capture-clipboard-image"),
    key("F", "capture-image-file"),
    key("i", "capture-inbox"),
    key("t", "today"),
    key("s", "search"),
    key("o", "open-at-point"),
    key("l", "link"),
    key("?", "status"),
    key("j", "jira"),
    key("g", "ingest"),
    key("G", "ingest-dry-run"),
    key("a", "proposals"),
    key("c", "capture (선택 글)", "x"),
    key("i", "capture-inbox (선택 글)", "x"),
  },
  opts = { root = root, prefix = prefix },
}
