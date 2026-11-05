-- Neovim 순정 옵션. 플러그인에 의존하지 않는다.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local o = vim.o

-- 인코딩: UTF-8 우선, 한글 레거시 인코딩 자동 판별
o.fileencodings = "ucs-bom,utf-8,cp949,euc-kr,latin1"
-- 기존 파일의 줄바꿈은 자동 판별하고, 새 파일은 LF로 만든다
o.fileformats = "unix,dos"

-- 화면
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.background = "dark"
o.scrolloff = 6
o.wrap = false
o.splitright = true
o.splitbelow = true
o.laststatus = 3
o.showmode = false

-- 들여쓰기
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true

-- 검색
o.ignorecase = true
o.smartcase = true

-- 동작
o.mouse = "a"
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true
o.completeopt = "menu,menuone,noselect"

-- 내장 터미널과 :! 명령은 PowerShell 7을 사용한다 (:help shell-powershell)
if vim.fn.executable("pwsh") == 1 then
  o.shell = "pwsh"
  o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command "
    .. "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();"
  o.shellredir = "2>&1 | %%{ \"$_\" } | Out-File %s; exit $LastExitCode"
  o.shellpipe = "2>&1 | %%{ \"$_\" } | Tee-Object %s; exit $LastExitCode"
  o.shellquote = ""
  o.shellxquote = ""
end

-- 클립보드 프로바이더 탐색이 시작 시간을 늘리지 않도록 뒤로 미룬다
vim.schedule(function()
  o.clipboard = "unnamedplus"
end)
