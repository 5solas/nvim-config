# Neovim Configuration Agent Guidelines

이 저장소를 수정하는 LLM 에이전트는 작업 전에 이 파일을 읽고 규칙을 따른다.

## Environment & Constraints

- OS: Windows native (PowerShell 7, Neovide, WezTerm).
- Target: Neovim 0.12+, Neovide 0.16+. Prefer native Lua APIs (`vim.keymap.set`, `vim.api.nvim_create_autocmd`, `vim.lsp.config`, `vim.lsp.enable`).
- Paths: use `vim.fn.stdpath()`, `vim.fs.joinpath()`, `vim.fs.normalize()`. Never hardcode user paths or Unix `/` roots.
- Encoding: UTF-8 by default, with `cp949`, `euc-kr` fallback in `fileencodings`.
- The config is the repo itself, linked by a junction: `%LOCALAPPDATA%\nvim` -> this repo. `lazy-lock.json` is written straight into the working tree.

## Architecture Rules

1. Package manager: `folke/lazy.nvim`. `init.lua` only loads `core` modules and bootstraps lazy.
2. One file, one domain: every plugin domain lives in `lua/plugins/<domain>.lua` and returns a valid lazy spec. Deleting that file must remove the feature without touching any other file.
3. No plugin-to-plugin coupling beyond a declared `dependencies` entry. `lua/core/` must not require a plugin, except through `pcall` or inside a user command.
4. Lazy loading: define `event`, `cmd`, `ft` or `keys`. Target: `nvim --startuptime` under 30 ms. nvim-treesitter is the documented exception (it does not support lazy loading, so keep its load cheap).
5. Keymaps: plugin keymaps go in the spec's `keys` table with `desc`. Plugin-free keymaps go in `lua/core/keymaps.lua`.

## Daemon Rules

The usual way to run this config is a headless server (`nvim --headless --listen <pipe>`) with Neovide attached through `--server`. See `README.md`.

- `init.lua` runs **before any UI exists**. Never gate startup settings on `vim.g.neovide`, `nvim_list_uis()` or `has("gui_running")`; they are false at that point. Neovide settings go in `lua/core/neovide.lua`, unconditionally.
- Never open a blocking prompt at startup (`vim.fn.input`, `confirm`). Nothing can answer it and every client would hang.
- Anything that needs a UI waits for the `UIEnter` autocmd.
- The daemon outlives many edits. Its environment (`PATH` and so on) is frozen at start; `nv --restart` picks up changes.

## Font Rules

Neovim draws on a cell grid, so a font's measured widths matter more than its reviews. Before changing `guifont`, measure the file (hmtx advance widths) and see the README's font section.

- Hangul must be exactly 2 Latin cells. Nerd "Mono" builds of CJK fonts can break this: D2Coding Nerd Font Mono measures 1.0.
- Ambiguous-width glyphs (`…`, `—`, `→`) must be 1 cell, which rules out Sarasa **Mono**; Sarasa Term and Fixed are fine. Any 2-cell exception needs a `setcellwidths` entry.
- A 0.6 em Latin font makes a 1.2 em Hangul slot. Hangul glyphs near 1.0 em then look spaced out.

## Plugin Curation Policy (Strict)

- Do not suggest deprecated plugins: `packer.nvim`, `null-ls`/`none-ls`, `nvim-tree`, `NERDTree`, `coc.nvim`.
- Select from what `nvim-lua/kickstart.nvim` and `LazyVim` use today. Before adding a plugin, check that the repo is not archived and was pushed to recently (`gh api repos/<owner>/<name>`).
- Before adding a plugin, check whether a Neovim built-in solves it (native commenting `gc`, built-in LSP client, default LSP maps).
- Do not rely on remembered plugin APIs: this ecosystem changes fast. nvim-treesitter's `main` branch, for example, is an incompatible rewrite of `master`. Read the plugin's current README.

## Change Routine

1. Check that `git status` is clean, `lazy-lock.json` included.
2. Make one change per commit: `feat(plugin): add gitsigns`.
3. Verify with `nvim --headless -c "luafile tests/smoke.lua"` and `pwsh -File tests/daemon.ps1` (it opens a Neovide window), then check `:Lazy profile`.
4. Rollback: delete the plugin's file, run `:Lazy clean`, then `git checkout .`.
5. After `:Lazy update` breaks something: `git checkout lazy-lock.json`, then `:Lazy restore`.
