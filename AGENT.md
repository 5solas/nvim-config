# Neovim Configuration Agent Guidelines

**Read this whole file before changing anything in this repo.** It is the single source of truth for LLM agents. `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` only point here, so edit this file and never copy rules into them.

Location: repo root, `D:\work\nvim-config\AGENT.md`, the same file as `%LOCALAPPDATA%\nvim\AGENT.md` through the junction. Do not move it or keep rules elsewhere. Human-facing explanation: `docs/USER_GUIDE.md`, section 10.

## Environment & Constraints

- OS: Windows native (PowerShell 7, Neovide, WezTerm).
- Target: Neovim 0.12+, Neovide 0.16+. Prefer native Lua APIs (`vim.keymap.set`, `vim.api.nvim_create_autocmd`, `vim.lsp.config`, `vim.lsp.enable`).
- Paths: use `vim.fn.stdpath()`, `vim.fs.joinpath()`, `vim.fs.normalize()`. Never hardcode user paths or Unix `/` roots.
- Encoding: UTF-8 by default, with `cp949`, `euc-kr` fallback in `fileencodings`.
- The config is the repo itself, linked by a junction: `%LOCALAPPDATA%\nvim` -> this repo. `lazy-lock.json` is written straight into the working tree.
- The repo is private. User docs are written in Korean.

## Adding a Feature: Required Steps

1. Run `git status`. It must be clean, `lazy-lock.json` included. If it is not, ask before mixing changes.
2. Check whether a Neovim built-in already solves it. For a plugin, follow the curation policy below and read its current README.
3. Put it in the right place:

   | Change | File |
   |---|---|
   | Option | `lua/core/options.lua` |
   | Plugin-free key | `lua/core/keymaps.lua` |
   | Plugin-free autocmd | `lua/core/autocmds.lua` |
   | Neovide or font setting | `lua/core/neovide.lua`, process settings in `neovide/config.toml` |
   | Daemon behavior | `lua/core/daemon.lua`, client in `bin/nvd.ps1` |
   | Plugin, including its keys | new `lua/plugins/<domain>.lua` |
   | LSP server, parser, formatter | `lua/plugins/lsp.lua`, `treesitter.lua`, `conform.lua` |
   | Own tool | `lua/tools/<name>.lua`, command registered in `plugin/<name>.lua` |
   | New external dependency | `scripts/install.ps1` |

4. Check it against the daemon rules: it must load with no UI and must never block on a prompt.
5. Check a new key with `maparg` under `nvim --clean`. If it overrides a built-in, say so in `docs/CUSTOMIZATIONS.md`. Check a new shell command name with `Get-Command <name>`.
6. Add a test for user-visible behavior: `tests/smoke.lua` (editor), `tests/daemon.ps1` (client, windows).
7. Run the tests and `:Lazy profile`. Restart the daemon first (`nvd --restart`): a running daemon does not reread the config.
8. Update the docs **in the same commit**:

   | If you changed | Update |
   |---|---|
   | Any option, key, autocmd, plugin, command or Neovide setting | `docs/CUSTOMIZATIONS.md`, marked with its source (자료, 요청 or 판단) |
   | Usage, or where a file lives | `docs/USER_GUIDE.md` |
   | Plugin list, or a design decision | `README.md` |
   | Anything a later agent could trip over | "Things to Remember" below |

9. Make one commit per change: `feat(plugin): add gitsigns`. Push only when the user asks.
10. Report what you verified and what you did not. Tests do not prove how something looks, so never claim a visual or IME result you have not seen.

Add only what was asked. A useful extra goes in the report as a suggestion, and if one is added anyway it is marked 판단 in `docs/CUSTOMIZATIONS.md`.

## Architecture Rules

1. Package manager: `folke/lazy.nvim`. `init.lua` only loads `core` modules and bootstraps lazy.
2. One file, one domain: every plugin domain lives in `lua/plugins/<domain>.lua` and returns a valid lazy spec. Deleting that file must remove the feature without touching any other file. Known exception: `lsp.lua` depends on blink.cmp.
3. No plugin-to-plugin coupling beyond a declared `dependencies` entry. `lua/core/` must not require a plugin, except through `pcall` or inside a user command.
4. Lazy loading: define `event`, `cmd`, `ft` or `keys`. Target: `nvim --startuptime` adds under 30 ms over `nvim --clean`. nvim-treesitter is the documented exception (it does not support lazy loading, so keep its load cheap).
5. Keymaps: plugin keymaps go in the spec's `keys` table with `desc`. Plugin-free keymaps go in `lua/core/keymaps.lua`.

## Daemon Rules

The usual way to run this config is a headless server (`nvim --headless --listen <pipe>`) with Neovide attached through `--server`. See `README.md`.

- `init.lua` runs **before any UI exists**. Never gate startup settings on `vim.g.neovide`, `nvim_list_uis()` or `has("gui_running")`; they are false at that point. Neovide settings go in `lua/core/neovide.lua`, unconditionally.
- Never open a blocking prompt at startup (`vim.fn.input`, `confirm`). Nothing can answer it and every client would hang.
- Anything that needs a UI waits for the `UIEnter` autocmd.
- The daemon outlives many edits. Its environment (`PATH` and so on) is frozen at start; `nvd --restart` picks up changes.

The client is named `nvd` because `nv` is PowerShell's built-in alias for `New-Variable`, and aliases win over scripts on PATH. Check `Get-Command <name>` before naming any command here.

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

## Things to Remember

Each of these went wrong once while building this config. Add new ones when you hit them.

**Daemon and client**

- `nvim --remote-expr` with captured stdout returned TUI escape codes instead of the result. Use `bin/nvd-rpc.lua` (`nvim -l` with `sockconnect` and `rpcrequest`).
- `:detach` right after `:q` hung the server (0.12.6, Windows). `lua/core/daemon.lua` closes the UI channels with `chanclose` instead.
- Do not detach while Neovim is asking a question: `:qa` on a modified buffer puts it in mode `r?`, and the UI must stay to answer. Keep that check.
- RPC to a daemon stuck on a prompt never returns, so `nvd-rpc.lua` has a 5 s timer that exits with code 3. Never add an unbounded wait to a client.
- After `:qa` the pipe is still visible for a moment while connections are refused. `nvd.ps1` retries for this reason.
- `:q` on a modified last window keeps the buffer in the daemon, unsaved. Do not describe this as saved.

**Startup**

- Lazy specs are evaluated on every start. `vim.fn.executable()` at spec level cost about 10 ms; do such checks inside `config`.
- Daemon startup must not depend on the network: Mason keeps `run_on_start = false`, and installs happen in `scripts/install.ps1`.

**Files and installation**

- `.gitignore` stays empty on purpose and `lazy-lock.json` stays tracked.
- `%LOCALAPPDATA%\nvim` and `%APPDATA%\neovide` are junctions, so writing through them edits tracked files here. Installers must refuse to overwrite an existing folder. The separate `work-kb-nvim` project must coexist with them.
- A user PATH change only reaches processes started afterward. A shell, or an agent's shell, started earlier will not find `nvd`; call `bin\nvd.ps1` by path or start a new shell.

**Tools**

- Never run `:CompileDb` automatically: `scons -n` executes the SConstruct, which is Python code.
- Raw compiledb gives `[]` on Windows logs. `gcc.exe` misses its regex and `src\foo.c` turns `\f` into a form feed, so keep `normalize_log` and `fix_mojibake`.
- After a build, `scons -n` prints only "up to date". That is why `.sconsign*` is hidden and restored around the run.
- conform's formatter name is `clang-format`, not `clang_format`. C and C++ have no LSP fallback, so code with no style file is never reformatted.
- `setcellwidths` applies only with `vim.g.nvim_daemon`: terminals draw those glyphs as 1 cell.
- `gr` is `nowait` in LSP buffers, which disables the built-in `grn`, `gra`, `grr`, `gri` and `grt` there. It also stops the wait for `timeoutlen`.

**Testing**

- `tests/daemon.ps1` opens real Neovide windows and overwrites `%LOCALAPPDATA%\neovide\neovide-settings.json` with a 500x500 window. After running it, delete that file and tell the user. It also needs a guarded timeout: a stuck daemon can block RPC.
- Use a dedicated `NV_PIPE` for any test, so the user's daemon and unsaved buffers are never touched.
- Call commands by name in at least one test, not only by path. Path-only tests are how the `nv` alias bug got through.

## Change Routine

1. Check that `git status` is clean, `lazy-lock.json` included.
2. Make one change per commit: `feat(plugin): add gitsigns`.
3. Verify with `nvim --headless -c "luafile tests/smoke.lua"` and `pwsh -File tests/daemon.ps1` (it opens a Neovide window), then check `:Lazy profile`.
4. Rollback: delete the plugin's file, run `:Lazy clean`, then `git checkout .`.
5. After `:Lazy update` breaks something: `git checkout lazy-lock.json`, then `:Lazy restore`.
