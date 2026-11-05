# nvim-config

Windows용 Neovim + Neovide 설정입니다. 헤드리스 Neovim을 파이프 데몬으로 띄워 두고 Neovide를 클라이언트로 붙입니다. 창을 닫아도 버퍼와 LSP가 그대로 남고, 다시 열 때는 플러그인 로딩 없이 바로 연결됩니다.

취지, 목표, 파일 위치, 사용법은 [사용자 안내서](docs/USER_GUIDE.md)에 정리되어 있습니다.

```text
PowerShell / cmd / 탐색기
        │  nvd file.c
        ▼
   bin/nvd.ps1 ──── nvim -l nvd-rpc.lua ────┐ 파일 열기, 상태 조회
        │                                 ▼
        │                  \\.\pipe\nvim-daemon-<user>
        │                                 ▲
        └── 창이 없으면 ── neovide --server ┘ 화면 표시
                                          │
                       nvim --headless --listen (숨김, 플러그인 미리 로드)
```

## 설치

필요한 것은 PowerShell 7과 scoop입니다. scoop이 없으면 빠진 도구 목록만 경고로 알려 줍니다.

```powershell
git clone https://github.com/5solas/nvim-config D:\work\nvim-config
pwsh -File D:\work\nvim-config\scripts\install.ps1            # 로그온 자동 시작까지 원하면 -Autostart
```

설치 스크립트가 하는 일이며, 다시 실행해도 안전합니다.

- 빠진 도구를 scoop으로 설치합니다: neovim, neovide, git, ripgrep, fzf, fd, tree-sitter, mingw, llvm, uv. compiledb와 scons는 `uv tool`로 설치합니다.
- Monoplex KR Nerd Font를 사용자 범위로 설치합니다. 버전과 해시를 고정합니다.
- 링크를 만듭니다: `%LOCALAPPDATA%\nvim` → 저장소, `%APPDATA%\neovide` → `neovide\`. 이미 다른 폴더가 있으면 덮어쓰지 않고 중단합니다.
- `bin\`을 사용자 PATH에 추가합니다. 프로필은 수정하지 않습니다.
- `lazy-lock.json` 버전으로 플러그인을 설치하고 Mason으로 LSP와 포맷터를 설치합니다.

`install.ps1 -Uninstall`은 링크, PATH 항목, 바로가기를 제거합니다.

## 사용법

```powershell
nvd                  # 열기. 데몬이 없으면 시작하고, 창이 있으면 그 창을 앞으로 가져온다
nvd src\main.c a.py  # 파일 열기. 상대 경로는 호출한 폴더 기준
nvd --tui            # 지금 터미널에서 데몬에 연결
nvd --status         # pid, UI 수, 수정된 버퍼, LSP
nvd --start          # 창 없이 데몬만 시작
nvd --stop           # 종료. 수정된 버퍼가 있으면 거부 (--force로 강제)
nvd --restart        # PATH 등 환경 변수를 바꾼 뒤 반영할 때
```

- PowerShell에서는 `nvd.ps1`이 현재 세션에서 바로 실행되고, cmd 등에서는 `nvd.cmd`가 pwsh를 거쳐 실행합니다.
- 이름이 `nv`가 아닌 이유는 PowerShell에서 `nv`가 `New-Variable`의 내장 별칭이기 때문입니다.
- 다른 폴더에서 `nvd`를 호출하면 새 탭을 열고 그 탭의 작업 폴더만 바꿉니다.
- `NV_PIPE`에 다른 파이프 이름을 지정하면 독립된 데몬을 하나 더 띄울 수 있습니다.

| 동작 | 결과 |
|---|---|
| 창 닫기, 마지막 창에서 `:q` `:wq` `ZZ` `ZQ` | UI만 분리. 데몬과 버퍼 유지 |
| `:qa` | 데몬 종료. 다음 `nvd`가 새로 시작 |
| 마지막 창에서 수정된 버퍼를 `:q` | 버퍼는 숨겨진 채 데몬에 남음. `:ls`로 확인, `nvd --stop`이 경고 |

데몬의 환경 변수는 시작 시점에 고정됩니다. PATH를 바꿨다면 `nvd --restart`를 실행합니다.

## 주요 키

리더는 `Space`입니다.

| 키 | 기능 | 키 | 기능 |
|---|---|---|---|
| `<leader>ff` | 파일 찾기 | `gd` / `gD` | 정의 / 선언 이동 |
| `<leader>fg` | 내용 검색 | `gr` | 참조 찾기 |
| `<leader>fb` | 버퍼 | `K` | 호버 |
| `<leader>fr` | 최근 파일 | `<leader>rn` | 이름 변경 |
| `-` | 폴더 편집 (oil) | `<leader>ca` | 코드 액션 |
| `]h` / `[h` | 다음 / 이전 변경 블록 | `<leader>cf` | 포맷 |
| `<leader>gs` / `<leader>gr` | 블록 스테이지 / 되돌리기 | `<C-=>` `<C-->` `<C-0>` | Neovide 확대, 축소, 초기화 |

## 플러그인

[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)과 [LazyVim](https://github.com/LazyVim/LazyVim)이 현재 채택한 목록을 기준으로 했고, 저장소 상태를 확인했습니다.

| 분류 | 플러그인 | 파일 |
|---|---|---|
| 패키지 관리 | lazy.nvim | `init.lua` |
| 테마 | tokyonight.nvim | `lua/plugins/colorscheme.lua` |
| 구문 분석 | nvim-treesitter (`main`) | `lua/plugins/treesitter.lua` |
| 탐색 | fzf-lua | `lua/plugins/fuzzy.lua` |
| LSP | 내장 `vim.lsp` + nvim-lspconfig + mason | `lua/plugins/lsp.lua` |
| 자동완성 | blink.cmp | `lua/plugins/cmp.lua` |
| 포맷 | conform.nvim | `lua/plugins/conform.lua` |
| 파일 편집 | oil.nvim | `lua/plugins/explorer.lua` |
| Git | gitsigns.nvim | `lua/plugins/git.lua` |

LSP: `lua_ls`, `pyright`, `ruff`, `rust_analyzer`, `clangd`. C/C++는 `.clang-format`이 있는 프로젝트에서만 저장 시 포맷합니다. 규칙이 없는 기존 코드가 통째로 재정렬되는 것을 막기 위해서입니다.

시작 시간은 개발 PC에서 약 100 ms이고, 그중 약 70 ms는 설정이 없어도 드는 `nvim --clean` 비용입니다. 설정이 더하는 몫은 약 30 ms입니다. 데몬이 떠 있으면 창을 여는 데 이 비용이 들지 않습니다.

## SCons 프로젝트: `:CompileDb`

SCons를 빌드하지 않고 `scons -n` 출력을 [compiledb](https://github.com/nickdiego/compiledb)로 파싱해 clangd가 쓰는 `compile_commands.json`을 만듭니다. 생성 후 clangd를 자동으로 재시작합니다.

```vim
:CompileDb                 " SConstruct를 위로 찾아 실행
:CompileDb debug=1 target  " 인자는 scons에 그대로 전달
```

`scons -n`이 SConstruct(Python)를 실행하므로 자동 실행하지 않습니다. C/C++ 파일을 열었을 때 데이터베이스가 없으면 안내만 표시합니다.

compiledb를 직접 쓰면 Windows의 SCons 로그에서 문제가 생겨 다음을 보정합니다 (compiledb 0.10.7, SCons 4.11.1).

| 문제 | 보정 |
|---|---|
| 빌드 후에는 `scons -n`이 `up to date`만 출력 | `.sconsign*`을 잠시 치웠다가 복원. 바이트 단위로 같고 재빌드도 일어나지 않음. 강제 종료로 백업이 남으면 다음 실행 때 복구 |
| `gcc.exe`가 컴파일러 정규식에 맞지 않고, `src\foo.c`의 `\f`가 폼피드로 해석되어 결과가 `[]` | 파싱 전에 `\`를 `/`로 바꾸고 `.exe`를 제거. `\"`는 유지 |
| 인자의 UTF-8 한글이 깨짐 | 파싱 후 되돌림 |

제약 사항입니다.

- MSVC `cl`은 compiledb가 파싱하지 못합니다. 그 경우 안내 메시지대로 SConstruct에서 SCons 내장 도구 `env.Tool('compilation_db')`와 `env.CompilationDatabase()`를 사용합니다.
- `VariantDir`의 `duplicate=1`(SCons 기본값)에서는 `file`이 복사본(`build/main.c`)을 가리킵니다. 원본을 열면 clangd가 가까운 항목의 플래그를 빌려 쓰며, 시험한 프로젝트에서는 오류 없이 동작했습니다. 파일별로 플래그가 다른 프로젝트라면 `duplicate=0`을 권합니다.
- `SConsignFile`로 서명 파일을 프로젝트 루트 밖에 둔 경우 치울 수 없어 안내 메시지를 표시합니다.
- 다른 터미널에서 `scons`가 빌드 중일 때는 실행하지 마세요. 서명 파일을 잠시 치우므로 빌드 상태가 꼬일 수 있습니다.
- 데몬의 환경으로 실행하므로, 툴체인을 PATH에 추가했다면 `nvd --restart`가 필요합니다.

## 폰트

```lua
vim.o.guifont = "Monoplex KR Nerd Font,Sarasa Fixed K:h12"
vim.o.linespace = 2
```

리뷰 글은 D2Coding과 Sarasa 계열을 많이 추천하지만 Neovim 격자 기준의 차이는 드러나지 않아, 후보의 폰트 파일을 직접 측정하고 같은 문장을 렌더링해 비교했습니다. "슬롯 채움"은 한글 2칸 폭 안에서 글자가 어떻게 보이는지를 뜻합니다.

| 폰트 | 한글:영문 | 슬롯 채움 | Nerd 아이콘 | 행 높이 | 판단 |
|---|---|---|---|---|---|
| **Monoplex KR Nerd Font** 1.2.1 | 2.00 | 자연스러움 (1.056em) | 내장 | 1.175em | **채택** |
| Sarasa Fixed K 1.0.43 | 2.00 | 자연스러움 (1.0em) | 없음 | 1.25em | **폴백**. 한자, 가나, 조합형 자모 전체 포함 |
| Sarasa Mono K | 2.00 | 자연스러움 | 없음 | 1.25em | 제외. `…` `—` `→` `①`이 2칸이라 격자와 어긋남 |
| JetBrainsMonoHangul NF Mono | 2.00 | 벌어짐 (1.2em 슬롯) | 내장 | 1.32em | 제외. `사 용 자`처럼 자간이 벌어짐 |
| Yeomil Mono NF | 2.00 | 벌어짐 (1.2em 슬롯) | 내장 | 1.30em | 제외. 같은 이유 |
| JetBrainsMono NF + Sarasa 폴백 | 2.00 | 벌어짐 (1.0em 글리프, 1.2em 슬롯) | 내장 | 1.32em | 제외. 같은 이유 |
| D2Coding 1.4.0 | 2.00 | 자연스러움 (1.0em) | 없음 | 1.16em | 제외. 행이 빠듯하고 `\|`가 `¦`처럼 보임 |
| D2Coding Nerd Font Mono | **1.00** | 2칸 자리에 1칸 글리프 | 내장 | 1.16em | 제외. scoop에 있는 판도 동일 |

Monoplex는 IBM Plex Mono와 IBM Plex Sans KR을 합친 OFL 폰트입니다. 측정 당시 최신 릴리스는 2026-11-03이고, 파일은 굵기당 4.7 MB로 Sarasa(23.7 MB)보다 가볍습니다.

Neovim 격자와 맞지 않는 부분은 설정으로 보정했습니다.

- 원문자(`①`, `❶`)는 Monoplex에서 2칸 글리프이므로 데몬에서 `setcellwidths`로 2칸으로 맞춥니다. 터미널은 1칸으로 그리므로 일반 `nvim`에는 적용하지 않습니다. `nvd --tui`로 볼 때는 이 문자만 어긋날 수 있습니다.
- 행 높이가 빠듯해 `linespace = 2`를 주고, 선 문자의 틈을 막기 위해 `box-drawing`은 `native`로 둡니다.
- 입력 모드에서만 IME를 켜서 노멀 모드 키가 한글 조합으로 빠지지 않게 합니다.
- 힌팅, 안티앨리어싱, 감마는 Neovide 기본값입니다.

참고 자료: [Sarasa Gothic 변형 차이](https://github.com/be5invis/Sarasa-Gothic), [Monoplex](https://github.com/y-kim/monoplex), [D2Coding](https://github.com/naver/d2-coding-font), [JetBrainsMonoHangul](https://github.com/Jhyub/JetBrainsMonoHangul), [Yeomil Mono](https://github.com/taevel02/yeomil-mono), [기계인간 John Grib: 코딩 폰트](https://johngrib.github.io/wiki/coding-font/), [한글 고정폭 폰트 4선](https://designnews.kr/collections/coding-monospace-fonts), [Neovide 설정 문서](https://neovide.dev/configuration.html).

## 구조

```text
init.lua              core 로드와 lazy 부트스트랩
AGENT.md              LLM 에이전트 규칙 원본 (CLAUDE.md, AGENTS.md, GEMINI.md가 연결)
docs/USER_GUIDE.md    사용자 안내서 (취지, 파일 위치, 사용법, 규칙 문서 위치)
docs/CUSTOMIZATIONS.md 순정 Neovim 대비 추가 내역과 출처
lazy-lock.json        플러그인 버전 고정
bin/                  nvd.ps1, nvd.cmd, nvd-rpc.lua
lua/core/             options, keymaps, autocmds, neovide, daemon
lua/plugins/          기능당 파일 하나
lua/tools/compiledb.lua, plugin/compiledb.lua
neovide/config.toml   Neovide 프로세스 설정
scripts/install.ps1
tests/smoke.lua       scons, compiledb, clangd, 인코딩, 포맷 통합 테스트
tests/daemon.ps1      실제 Neovide 창으로 nvd 통합 테스트
```

## 일상 운영

```powershell
nvim --headless -c "luafile tests/smoke.lua"
pwsh -File tests/daemon.ps1
```

- 새 플러그인 실험: 파일 하나를 추가해 시험합니다. 마음에 안 들면 그 파일을 지우고 `:Lazy clean`, `git checkout .`
- `:Lazy update` 후 문제가 생기면: `git checkout lazy-lock.json` 후 `:Lazy restore`
- 시작 시간 확인: `:Lazy profile`

방법론은 "바닐라 + LLM 큐레이션" 방식의 모듈형 점진 구축을 따랐고, 커밋 기록이 그 단계를 따라갑니다.
