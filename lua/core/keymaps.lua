-- 플러그인과 무관한 순정 키맵. 플러그인 키맵은 각 spec의 keys에 둔다.
local map = vim.keymap.set

map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })

map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

map("n", "[b", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "]b", "<Cmd>bnext<CR>", { desc = "Next buffer" })

map("n", "<leader>w", "<Cmd>write<CR>", { desc = "Write buffer" })
map("n", "<leader>xd", vim.diagnostic.setloclist, { desc = "Diagnostics to location list" })
