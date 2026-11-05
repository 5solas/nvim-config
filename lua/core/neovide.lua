-- Neovide 설정. 데몬의 init.lua는 UI가 붙기 전에 실행되어 이 시점에는 vim.g.neovide가 없다.
-- 그래서 조건 없이 설정한다. 터미널 UI에서는 쓰이지 않을 뿐 해가 없다.
local g = vim.g

-- 선정 근거와 측정값은 README의 "폰트" 절에 있다.
-- Monoplex KR Nerd Font: 한글:영문 정확히 2:1, 한글이 2칸을 꽉 채움, Nerd 아이콘 내장.
-- Sarasa Fixed K: Monoplex에 없는 한자, 가나, 조합형 자모(macOS NFD 파일명)를 담당한다.
-- Sarasa Mono K는 쓰지 않는다. … — → 글리프가 2칸인데 Neovim 격자는 1칸으로 잡아 겹친다.
vim.o.guifont = "Monoplex KR Nerd Font,Sarasa Fixed K:h12"
-- Monoplex의 기본 행 높이(1.175em)는 한글에 빠듯해서 2px 늘린다
vim.o.linespace = 2

-- Monoplex의 원문자는 2칸 글리프라 Neovim 격자도 2칸으로 맞춘다. 격자를 쓰는 Neovide 데몬에만 적용한다.
-- 터미널은 원문자를 1칸으로 그리므로 일반 nvim에는 적용하지 않는다.
if vim.g.nvim_daemon then
  vim.fn.setcellwidths({ { 0x2460, 0x24FF, 2 }, { 0x2776, 0x277F, 2 } })
end

-- 창을 닫아도 데몬은 살려 두고 UI만 분리한다
g.neovide_detach_on_quit = "always_detach"
g.neovide_remember_window_size = true
g.neovide_cursor_animation_length = 0.05
g.neovide_cursor_trail_size = 0.3
g.neovide_scroll_animation_length = 0.15

-- 입력 모드에서만 IME를 켠다. 노멀 모드 키가 한글 조합으로 빠지지 않게 한다.
g.neovide_input_ime = false
local group = vim.api.nvim_create_augroup("core_neovide", { clear = true })
local function ime(enabled)
  return function()
    g.neovide_input_ime = enabled
  end
end
vim.api.nvim_create_autocmd("InsertEnter", { group = group, callback = ime(true) })
vim.api.nvim_create_autocmd("InsertLeave", { group = group, callback = ime(false) })
vim.api.nvim_create_autocmd("CmdlineEnter", { group = group, pattern = "[/\\?]", callback = ime(true) })
vim.api.nvim_create_autocmd("CmdlineLeave", { group = group, pattern = "[/\\?]", callback = ime(false) })

-- 글꼴 확대/축소
g.neovide_scale_factor = 1.0
local function zoom(delta)
  return function()
    g.neovide_scale_factor = delta == 0 and 1.0 or g.neovide_scale_factor * delta
  end
end
vim.keymap.set({ "n", "i", "t" }, "<C-=>", zoom(1.1), { desc = "Neovide zoom in" })
vim.keymap.set({ "n", "i", "t" }, "<C-->", zoom(1 / 1.1), { desc = "Neovide zoom out" })
vim.keymap.set({ "n", "i", "t" }, "<C-0>", zoom(0), { desc = "Neovide zoom reset" })
