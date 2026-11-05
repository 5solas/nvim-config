# 기본값 대비 추가 내역

순정 Neovim과 비교해 이 설정이 무엇을 바꾸고 더했는지 정리한 목록입니다. 옵션과 키의 기본값은 Neovim 0.12.6에서 `nvim --clean`을 실행해 확인했습니다 (2026-11-06).

**출처 표기**

- **자료:** 처음 받은 참고 자료("모듈형 점진적 구축 방법론")에 명시된 항목
- **요청:** 대화에서 요청한 기능. 구체적인 값이나 구현 방법은 Claude가 정했습니다
- **판단:** 요청에 없었지만 Claude가 판단해 추가한 항목. **지워도 다른 기능이 망가지지 않는지 먼저 "지울 때" 안내를 보세요**

Neovim 설치 폴더의 파일은 수정하지 않았습니다. 아래 내용은 모두 이 저장소에 있습니다.

## 옵션 (`lua/core/options.lua`)

| 옵션 | 기본값 | 이 설정 | 이유 | 출처 |
|---|---|---|---|---|
| `mapleader` | 없음 | `Space` | 리더 키 | 판단 |
| `maplocalleader` | 없음 | `\` | 로컬 리더 키 | 판단 |
| `fileencodings` | `ucs-bom,utf-8,default,latin1` | `ucs-bom,utf-8,cp949,euc-kr,latin1` | 한글 레거시 파일 자동 판별 | 자료 |
| `fileformats` | `dos,unix` | `unix,dos` | 새 파일은 LF로 생성. 기존 파일은 자동 판별 | 판단 |
| `number` | 끔 | 켬 | 행 번호 | 자료 |
| `relativenumber` | 끔 | 켬 | `5j` 같은 이동을 쉽게 | 판단 |
| `signcolumn` | `auto` | `yes` | 진단과 Git 표시가 나타날 때 화면이 밀리지 않게 | 판단 |
| `cursorline` | 끔 | 켬 | 현재 행 강조 | 판단 |
| `termguicolors` | 터미널에 따라 자동 | 켬 | 24비트 색상 | 판단 |
| `scrolloff` | `0` | `6` | 커서 위아래 여백 | 판단 |
| `wrap` | 켬 | 끔 | 코드 행 줄바꿈 안 함 | 판단 |
| `splitright`, `splitbelow` | 끔 | 켬 | 새 분할을 오른쪽, 아래에 | 판단 |
| `laststatus` | `2` | `3` | 상태 줄을 전체에 하나만 | 판단 |
| `showmode` | 켬 | 끔 | 상태 줄과 중복되는 모드 표시 제거 | 판단 |
| `expandtab` | 끔 | 켬 | 탭 대신 공백 | 자료(들여쓰기) |
| `shiftwidth`, `tabstop` | `8` | `4` | 들여쓰기 4칸 | 자료(들여쓰기) |
| `softtabstop` | `0` | `4` | 들여쓰기 4칸 | 자료(들여쓰기) |
| `smartindent` | 끔 | 켬 | 자동 들여쓰기 | 자료(들여쓰기) |
| `ignorecase`, `smartcase` | 끔 | 켬 | 소문자로 검색하면 대소문자 무시 | 판단 |
| `mouse` | `nvi` | `a` | 모든 모드에서 마우스 사용 | 판단 |
| `undofile` | 끔 | 켬 | 파일을 닫아도 실행 취소 기록 유지 | 판단 |
| `updatetime` | `4000` | `250` | 스왑 기록과 CursorHold를 빠르게 | 판단 |
| `timeoutlen` | `1000` | `400` | 키 조합 대기 시간 단축 | 판단 |
| `confirm` | 끔 | 켬 | 저장 안 된 버퍼를 닫을 때 오류 대신 질문. 데몬의 `:qa` 동작이 이 옵션을 전제로 합니다 | 판단 |
| `completeopt` | `menu,popup` | `menu,menuone,noselect` | 첫 항목 자동 선택 안 함 | 판단 |
| `shell` 외 5개 | `cmd.exe` | `pwsh` | `:!`과 내장 터미널에서 PowerShell 7 사용, UTF-8 출력. `pwsh`가 없으면 적용 안 됨 | 판단 |
| `clipboard` | 없음 | `unnamedplus` | 시스템 클립보드 연동. 시작 시간을 위해 뒤로 미룸 | 자료 |
| `guifont` | `Cascadia Code,...` | `Monoplex KR Nerd Font,Sarasa Fixed K:h12` | 선정 근거는 README 폰트 절 | 요청 |
| `linespace` | `0` | `2` | 한글 행 높이 확보 | 요청 |

`background=dark`도 파일에 적혀 있지만 기본값과 같습니다.

## 키

### 순정 동작을 덮어쓰는 키

**쓰던 키의 동작이 달라지는 부분이므로 먼저 확인하세요.**

| 키 | 순정 동작 | 이 설정 | 출처 |
|---|---|---|---|
| `<C-l>` | 검색 강조 해제와 화면 다시 그리기 | 오른쪽 창으로 이동. 강조 해제는 `<Esc>`로 옮김 | 판단 |
| `<C-h>` | 커서 왼쪽 이동 | 왼쪽 창으로 이동 | 판단 |
| `<C-j>` | 커서 아래 이동 | 아래 창으로 이동 | 판단 |
| `<C-k>` | 동작 없음 | 위 창으로 이동 | 판단 |
| `<Esc>` (노멀) | 동작 없음 | 검색 강조 해제 | 판단 |
| `-` | 윗줄 첫 글자로 이동 | oil로 현재 폴더 열기 | 판단 (oil 선택은 자료) |
| `gr` | LSP 내장 묶음 `grn` `gra` `grr` `gri` `grt`의 접두사 | **LSP가 붙은 버퍼에서** 바로 참조 찾기. 이 버퍼에서는 위 내장 키를 쓸 수 없고 `<leader>rn`, `<leader>ca`를 씁니다 | 자료 |

### 새로 추가한 키

| 키 | 기능 | 위치 | 출처 |
|---|---|---|---|
| `<leader>w` | 저장 | `lua/core/keymaps.lua` | 판단 |
| `<leader>xd` | 진단을 위치 목록으로 | `lua/core/keymaps.lua` | 판단 |
| `<Esc><Esc>` (터미널) | 터미널 모드 나가기 | `lua/core/keymaps.lua` | 판단 |
| `gd`, `gD` | 정의, 선언으로 이동 (LSP 버퍼) | `lua/plugins/lsp.lua` | `gd`는 자료, `gD`는 판단 |
| `<leader>rn`, `<leader>ca` | 이름 변경, 코드 액션 | `lua/plugins/lsp.lua` | 판단 |
| `<leader>cf` | 포맷 | `lua/plugins/conform.lua` | 판단 |
| `<leader>ff` `fg` `fb` `fr` `fh` `fd` `f.` | 파일, 내용, 버퍼, 최근 파일, 도움말, 진단, 검색 이어서 | `lua/plugins/fuzzy.lua` | 판단 |
| `]h` `[h` | 다음, 이전 변경 블록 | `lua/plugins/git.lua` | 판단 |
| `<leader>gs` `gr` `gp` `gb` `gd` | 스테이지, 되돌리기, 미리 보기, blame, diff | `lua/plugins/git.lua` | 스테이지·되돌리기는 자료, 나머지는 판단 |
| `<C-=>` `<C-->` `<C-0>` | Neovide 확대, 축소, 초기화 | `lua/core/neovide.lua` | 판단 |
| `<leader>kc` `kC` `kF` `ki` `kt` `ks` `ko` `kl` `k?` `kj` `kg` `kG` `ka` | work-kb: 캡처, 클립보드 이미지, 이미지 파일, inbox, 오늘 daily, 검색, 커서 위치 열기, link, 상태, Jira, 편찬, 편찬 미리 보기, 주제 제안 승인. `WORK_KB_ROOT`가 있을 때만 | `lua/plugins/work-kb.lua`가 첫 사용 때 불러오고, 실제 키는 플러그인의 `setup()`이 만듦 | 요청 |
| `<leader>kc` `ki` (비주얼) | work-kb: 선택한 글로 캡처, inbox | 같음 | 요청 |

`]b`, `[b`도 파일에 있지만 순정과 같은 동작이어서 달라지는 것은 없습니다. `K`, `gc`는 Neovim 내장 기능을 그대로 씁니다.

자동완성 키는 blink.cmp의 `default` 프리셋입니다. `<C-space>` 열기, `<C-y>` 선택, `<C-e>` 취소, `<C-n>` `<C-p>` 이동, `<C-b>` `<C-f>` 문서 스크롤, `<Tab>` `<S-Tab>` 스니펫 이동, `<C-k>` 시그니처 표시입니다.

## 자동 명령

| 언제 | 동작 | 위치 | 출처 |
|---|---|---|---|
| 복사할 때 | 복사한 영역을 잠깐 강조 | `lua/core/autocmds.lua` | 판단 |
| 파일을 열 때 | 마지막 커서 위치로 이동 | `lua/core/autocmds.lua` | 판단 |
| 창 크기가 바뀔 때 | 분할 크기를 고르게 맞춤 | `lua/core/autocmds.lua` | 판단 |
| 파일 저장 전 | 포맷 (conform) | `lua/plugins/conform.lua` | 자료 |
| 파일 유형이 정해질 때 | Tree-sitter 구문 강조와 들여쓰기 시작 | `lua/plugins/treesitter.lua` | 자료(treesitter) |
| LSP가 붙을 때 | LSP 키 등록 | `lua/plugins/lsp.lua` | 자료 |
| C/C++ 파일을 열 때 | `compile_commands.json`이 없으면 안내 표시. 실행은 하지 않음 | `plugin/compiledb.lua` | 판단 |
| 입력 모드, 검색 진입과 이탈 | IME 켜기와 끄기 | `lua/core/neovide.lua` | 요청(한글 처리) |
| 마지막 창의 `:q` | 데몬 대신 창만 분리 | `lua/core/daemon.lua` | 요청(데몬) |
| 데몬 시작 직후 | 지연 로드 플러그인 미리 로드 | `lua/core/daemon.lua` | 판단 |
| work-kb를 불러온 뒤 | 볼트의 `.md`에 `autoread`, 새 `.md`는 UTF-8과 LF. 0.3초 뒤 보조 프로세스 `kb.py serve` 시작, 종료할 때 정리. 데몬에서는 위 미리 로드 때문에 시작 직후 일어남 | work-kb 플러그인 (`lua/plugins/work-kb.lua`가 불러옴) | 요청 |

## 명령

| 명령 | 기능 | 출처 |
|---|---|---|
| `nvd` (셸) | 데몬 관리, 파일 열기. `bin/` | 요청 |
| `:CompileDb` | `compile_commands.json` 생성. `lua/tools/compiledb.lua` | 요청 |
| `:WorkKb [이름]` | work-kb 기능 실행. 이름 없이 실행하면 목록 표시. 플러그인이 정의하고 `lua/plugins/work-kb.lua`가 첫 사용 때 불러옴. `WORK_KB_ROOT`가 있을 때만 | 요청 |

## 플러그인과 도구

플러그인 선택은 참고 자료의 표에서 골랐습니다. 대안이 함께 적혀 있던 항목은 Claude가 그중 하나를 정했습니다. 아래 "기본값과 다른 설정"에 없는 항목은 플러그인 기본값입니다.

| 플러그인 | 파일 | 기본값과 다른 설정 | 출처 |
|---|---|---|---|
| lazy.nvim | `init.lua` | 아래 별도 설명 | 자료 |
| tokyonight.nvim | `lua/plugins/colorscheme.lua` | `tokyonight-night` 테마 | 판단 |
| nvim-treesitter (`main`) | `lua/plugins/treesitter.lua` | 파서 15종: bash, c, cpp, json, lua, markdown, markdown_inline, powershell, python, query, rust, toml, vim, vimdoc, yaml | 자료 |
| fzf-lua | `lua/plugins/fuzzy.lua` | 없음 | 자료 |
| nvim-lspconfig, mason, mason-tool-installer | `lua/plugins/lsp.lua` | 시작 시 자동 설치 끔 (데몬 시작이 네트워크에 묶이지 않게) | 자료 (installer는 판단) |
| blink.cmp | `lua/plugins/cmp.lua` | 문서 300ms 후 자동 표시, 시그니처 도움말 켬 | 자료 |
| conform.nvim | `lua/plugins/conform.lua` | 저장 시 포맷. C/C++는 `.clang-format`이 있을 때만 | 자료 (C/C++ 조건은 판단) |
| oil.nvim | `lua/plugins/explorer.lua` | 없음 | 자료 |
| gitsigns.nvim | `lua/plugins/git.lua` | 없음 | 자료 |
| work-kb (다른 저장소의 로컬 플러그인, `<WORK_KB_ROOT>\nvim`) | `lua/plugins/work-kb.lua` | `root`를 `WORK_KB_ROOT`로, 접두 키를 `<leader>k`로 지정. 변수나 플러그인 폴더가 없으면 spec이 비어 아무것도 더하지 않음. `lazy-lock.json`에 들어가지 않음 | 요청 |

**언어 서버:** `lua_ls`, `pyright`, `ruff`, `rust_analyzer`는 자료, `clangd`는 compiledb 요청에 따라 추가했습니다. clangd에는 `--background-index`, `--header-insertion=never`, `--query-driver`를 줍니다. `lua_ls`는 LuaJIT과 Neovim 런타임을 인식하도록 설정했습니다.

**포맷터:** stylua, ruff, rustfmt, clang-format.

**lazy.nvim 설정 (`init.lua`):**

- 기본을 지연 로드로 둡니다 (`defaults.lazy = true`).
- 업데이트 자동 확인과 설정 변경 감지를 끕니다. 데몬이 알림 없이 조용히 동작하게 하기 위해서입니다.
- luarocks 지원을 끕니다.
- `vim.loader`를 켜서 Lua 모듈 로딩을 캐시합니다.

**꺼 둔 내장 플러그인 (판단):** `gzip`, `netrwPlugin`, `tarPlugin`, `tohtml`, `tutor`, `zipPlugin`. 시작 시간을 줄이려는 설정이며 **다음 기능을 쓸 수 없게 됩니다.**

| 사라지는 기능 | 대신 쓸 것 또는 복구 방법 |
|---|---|
| `:Explore` 등 netrw 폴더 보기 | oil (`-`) |
| `.gz` `.zip` `.tar` 파일을 편집기에서 바로 열기 | `init.lua`의 `disabled_plugins`에서 항목 제거 |
| `:Tutor` | 같음 |
| `:TOhtml` | 같음 |

## Neovide 설정

| 항목 | 값 | 이유 | 위치 | 출처 |
|---|---|---|---|---|
| `neovide_detach_on_quit` | `always_detach` | 창을 닫아도 데몬 유지 | `lua/core/neovide.lua` | 요청(데몬) |
| `neovide_input_ime` | 입력 모드, 검색에서만 켬 | 노멀 모드 키가 한글 조합으로 빠지지 않게 | `lua/core/neovide.lua` | 요청(한글 처리) |
| `setcellwidths` | 원문자 2칸 (데몬에서만) | Monoplex 글리프 폭과 격자를 맞춤 | `lua/core/neovide.lua` | 요청(폰트) |
| `neovide_scale_factor` | `1.0`에서 시작 | 확대, 축소 키가 바꾸는 값 | `lua/core/neovide.lua` | 판단 |
| `neovide_remember_window_size` | 켬 | 창 크기 기억 | `lua/core/neovide.lua` | 판단 |
| `neovide_cursor_animation_length` | `0.05` | 커서 애니메이션 단축 | `lua/core/neovide.lua` | 판단 |
| `neovide_cursor_trail_size` | `0.3` | 커서 꼬리 축소 | `lua/core/neovide.lua` | 판단 |
| `neovide_scroll_animation_length` | `0.15` | 스크롤 애니메이션 단축 | `lua/core/neovide.lua` | 판단 |
| `fork` | `true` | 호출한 터미널을 붙잡지 않음 | `neovide/config.toml` | 판단 |
| `tabs` | `false` | Neovide에 직접 넘긴 파일을 탭으로 열지 않음. 이 설정에서는 파일 열기를 데몬이 맡음 | `neovide/config.toml` | 판단 |
| `box-drawing.mode` | `native` | `linespace`로 생기는 선 문자 틈 제거 | `neovide/config.toml` | 요청(폰트) |

## 저장소 파일

| 파일 | 내용 | 출처 |
|---|---|---|
| `AGENT.md` | LLM 에이전트 규칙 | 자료 (내용은 데몬, 폰트, 기억할 점으로 확장) |
| `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | 에이전트별 진입 파일. `AGENT.md`로 연결 | `CLAUDE.md`는 자료, 나머지는 판단 |
| `lazy-lock.json`, 빈 `.gitignore` | 플러그인 버전 추적 | 자료 |
| `.gitattributes` | 줄바꿈을 LF로 고정하고 `.cmd`만 CRLF로 유지 | 판단 |
| `scripts/install.ps1` | 설치와 제거 | 판단 |
| `tests/smoke.lua`, `tests/daemon.ps1` | 통합 테스트 | 판단 |
| `README.md`, `docs/` | 문서 | `docs/USER_GUIDE.md`, 이 문서는 요청 |

## 저장소 밖에 추가한 것

정션, PATH, 폰트, 도구, 데이터 폴더의 위치는 [사용자 안내서 3절](USER_GUIDE.md#3-파일-위치)에 있습니다.

## 되돌리는 방법

| 항목 | 방법 |
|---|---|
| 옵션 하나 | `lua/core/options.lua`에서 해당 줄 삭제 |
| 키 하나 | 해당 파일에서 줄 삭제 |
| 플러그인 하나 | `lua/plugins/`의 파일을 지우고 `:Lazy clean`. **단, `lua/plugins/lsp.lua`는 blink.cmp에 의존합니다** (`dependencies`와 `get_lsp_capabilities`). `cmp.lua`를 지워도 `lsp.lua`가 blink.cmp를 다시 받아 오므로, 자동완성까지 없애려면 `lsp.lua`도 함께 고쳐야 합니다 |
| work-kb | `lua/plugins/work-kb.lua`를 지우거나 `WORK_KB_ROOT`를 없앱니다. 로컬 폴더 플러그인이라 `:Lazy clean`은 work-kb 저장소를 지우지 않습니다 |
| `confirm` | 지우면 수정된 버퍼의 `:qa`가 질문 없이 오류로 끝납니다 |
| 전체 | [사용자 안내서 8절](USER_GUIDE.md#8-제거) |

어느 경우든 고친 뒤 `nvd --restart`를 실행해야 반영됩니다.
