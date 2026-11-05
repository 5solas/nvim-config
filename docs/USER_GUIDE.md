# nvim-config 사용자 안내서

Windows에서 Neovim을 백그라운드에 띄워 두고 Neovide 창을 붙였다 뗐다 하며 쓰는 개인 개발 환경입니다. 이 문서는 왜 이렇게 만들었는지, 파일이 어디에 있어야 하는지, 어떻게 쓰고 고치는지를 설명합니다.

처음이라면 [설치](#4-설치)를 마친 뒤 [사용법](#5-사용법)으로 넘어가세요. 설계 근거와 측정값은 [README](../README.md)에, 순정 Neovim과 달라진 점의 전체 목록은 [기본값 대비 추가 내역](CUSTOMIZATIONS.md)에, LLM 에이전트용 규칙은 [AGENT.md](../AGENT.md)에 있습니다.

## 1. 취지

보통의 Neovim은 창을 닫으면 프로세스가 끝납니다. 열어 둔 버퍼, 언어 서버(LSP)의 분석 결과가 함께 사라지고, 다시 열 때마다 처음부터 준비해야 합니다. C/C++ 프로젝트에서는 특히 이 대기 시간이 큽니다.

그래서 **편집기 본체와 화면을 분리**했습니다. 화면이 없는 Neovim(데몬)이 계속 실행되면서 작업 상태를 들고 있고, Neovide 창은 데몬을 보여 주기만 합니다. 창을 닫아도 작업은 그대로 남습니다.

함께 해결하려 한 문제는 다음과 같습니다.

- PowerShell이나 cmd에서 명령 하나로 파일을 열고 싶습니다.
- 한글이 격자에서 어긋나지 않아야 하고, 노멀 모드 키가 한글 조합으로 입력되지 않아야 합니다.
- 설정이 커져서 무엇이 무엇인지 모르게 되는 상황을 피해야 합니다.
- SCons 프로젝트에서 재빌드 없이 clangd를 쓸 수 있어야 합니다.

## 2. 목표

| 목표 | 구현 방법 | 확인된 결과 |
|---|---|---|
| 창을 닫아도 작업 유지 | 헤드리스 데몬 + Neovide 클라이언트 | 버퍼, 탭, 데몬 프로세스 유지 |
| 빠른 창 열기 | 플러그인을 데몬에 미리 로드 | 데몬이 떠 있으면 창 연결까지 약 0.4초 |
| 어디서든 호출 | PATH에 있는 `nvd` 명령 | PowerShell, cmd에서 이름으로 실행 |
| 가벼운 시작 | 플러그인 지연 로드 | 설정이 더하는 시간 약 30 ms |
| 한글 표시 | 폭을 측정해 고른 폰트 | 한글:영문 폭 정확히 2:1 |
| 쉽게 넣고 빼는 기능 | 기능당 파일 하나 (`lua/plugins/`) | 파일을 지우면 그 기능만 사라짐 |
| 재현 가능한 설치 | 저장소 하나 + `lazy-lock.json` + 설치 스크립트 | 플러그인 버전 고정 |
| 재빌드 없는 clangd 연동 | `:CompileDb` | 빌드 없이 `compile_commands.json` 생성 |

**범위 밖:** Windows 외 운영체제는 지원하지 않습니다. 플러그인을 많이 넣는 것도 목표가 아니어서, 기능이 필요해질 때 파일 단위로 추가합니다.

## 3. 파일 위치

### 전체 구조

```text
 PowerShell / cmd
       │  nvd file.c
       ▼
 bin\nvd.ps1 ──── 파일 열기, 상태 조회 ───┐
       │                                 ▼
       │                 \\.\pipe\nvim-daemon-<사용자명>
       │                                 ▲
       └── 창이 없으면 ── neovide --server ┘ 화면 표시
                                         │
                      nvim --headless --listen (숨김, 작업 상태 보관)
```

### 어디에 무엇이 있어야 하나

핵심은 **설정의 원본이 저장소 한 곳뿐**이라는 점입니다. Neovim과 Neovide가 찾는 표준 위치에는 저장소로 연결되는 링크(정션)만 둡니다. 아래 위치는 모두 `install.ps1`이 만들어 주므로 직접 복사할 필요가 없습니다.

| 위치 | 내용 | 만드는 주체 | git 포함 |
|---|---|---|---|
| `D:\work\nvim-config` | **설정 원본.** 다른 경로로 받아도 됩니다 | `git clone` | 포함 |
| `%LOCALAPPDATA%\nvim` | 저장소로 가는 정션. Neovim이 설정을 읽는 위치 | `install.ps1` | 제외 |
| `%APPDATA%\neovide` | 저장소 `neovide\`로 가는 정션. Neovide가 `config.toml`을 읽는 위치 | `install.ps1` | 제외 |
| 사용자 PATH | 저장소 `bin\` 폴더 추가 | `install.ps1` | 제외 |
| `%LOCALAPPDATA%\nvim-data\lazy` | 플러그인 코드 | lazy.nvim | 제외 |
| `%LOCALAPPDATA%\nvim-data\mason` | 언어 서버, 포맷터 | mason | 제외 |
| `%LOCALAPPDATA%\nvim-data\site` | Tree-sitter 파서 | nvim-treesitter | 제외 |
| `%LOCALAPPDATA%\nvim-data\undo`, `swap`, `shada` | 실행 취소 기록, 스왑 파일, 편집 이력 | Neovim | 제외 |
| `%LOCALAPPDATA%\neovide\neovide-settings.json` | Neovide 창 크기와 위치 | Neovide | 제외 |
| `%LOCALAPPDATA%\Microsoft\Windows\Fonts\MonoplexKRNerdFont-*.ttf` | 주 폰트 4종 (사용자 범위) | `install.ps1` | 제외 |
| `%USERPROFILE%\scoop` | neovim, neovide, ripgrep, llvm 등 외부 도구 | scoop | 제외 |
| 시작프로그램 폴더의 `nvim-daemon.lnk` | 로그온 시 데몬 시작. `-Autostart`를 줬을 때만 생성 | `install.ps1` | 제외 |

프로젝트 쪽에 두는 파일도 있습니다.

| 위치 | 내용 |
|---|---|
| `SConstruct`와 같은 폴더의 `compile_commands.json` | `:CompileDb`가 생성합니다. 프로젝트의 `.gitignore`에 넣기를 권합니다 |
| 프로젝트 안의 `.clang-format` | 있으면 C/C++ 파일을 저장할 때 포맷하고, 없으면 포맷하지 않습니다 |

### 경로 규칙

- **저장소는 어디에 받아도 됩니다.** 설치 스크립트가 자기 위치를 기준으로 링크를 만듭니다. 파일 이름과 폴더 구조만 유지하면 됩니다.
- **`%LOCALAPPDATA%\nvim`에 파일을 직접 넣지 마세요.** 정션이라 그 안의 파일은 곧 저장소 파일이고, 변경 사항은 `git status`에 나타납니다.
- **이미 `%LOCALAPPDATA%\nvim`이 있으면** 설치 스크립트가 덮어쓰지 않고 중단합니다. 기존 폴더를 다른 곳으로 옮긴 뒤 다시 실행하세요.
- **저장소를 옮길 때는 순서를 지키세요.** 정션은 옛 경로를 계속 가리키므로, 옮기기 전에 해제해야 합니다.

  ```powershell
  nvd --stop
  pwsh -File D:\work\nvim-config\scripts\install.ps1 -Uninstall   # 옛 위치에서 먼저 실행
  Move-Item D:\work\nvim-config E:\새위치\nvim-config
  pwsh -File E:\새위치\nvim-config\scripts\install.ps1            # 새 위치에서 다시 설치
  ```

### 저장소 내부

| 경로 | 역할 |
|---|---|
| `init.lua` | 진입점. `core` 모듈을 읽고 lazy.nvim을 준비합니다 |
| `lazy-lock.json` | 플러그인 버전 고정. git으로 관리합니다 |
| `bin\nvd.ps1` | `nvd` 명령 본체 |
| `bin\nvd.cmd` | cmd 등 PowerShell 밖에서 호출할 때의 입구 |
| `bin\nvd-rpc.lua` | 데몬과 통신하는 보조 스크립트 (5초 제한) |
| `lua\core\options.lua` | 기본 옵션 (인코딩, 들여쓰기, 셸) |
| `lua\core\keymaps.lua` | 플러그인과 무관한 키 |
| `lua\core\autocmds.lua` | 자동 명령 |
| `lua\core\neovide.lua` | 폰트, IME, 확대/축소, 커서 애니메이션 |
| `lua\core\daemon.lua` | 데몬 쪽 기능 (파일 열기, 상태, 창 분리) |
| `lua\plugins\*.lua` | 플러그인 설정. **기능당 파일 하나** |
| `lua\tools\compiledb.lua`, `plugin\compiledb.lua` | `:CompileDb` 구현과 명령 등록 |
| `neovide\config.toml` | Neovide 프로세스 설정 |
| `scripts\install.ps1` | 설치와 제거 |
| `tests\smoke.lua`, `tests\daemon.ps1` | 통합 테스트 |
| `docs\USER_GUIDE.md` | 이 문서 |
| `docs\CUSTOMIZATIONS.md` | 순정 Neovim 대비 추가, 변경한 항목과 그 출처 |
| `AGENT.md` | LLM 에이전트 규칙의 원본. [10절](#10-llm-에이전트-규칙-문서) 참고 |
| `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | 에이전트별 진입 파일. `AGENT.md`로 연결만 합니다 |

## 4. 설치

**준비물:** Windows 11(개발과 시험에 사용한 환경), PowerShell 7(`pwsh`), [scoop](https://scoop.sh), git. scoop이 없으면 스크립트가 빠진 도구를 경고로만 알려 주므로 직접 설치해야 합니다.

```powershell
git clone https://github.com/5solas/nvim-config D:\work\nvim-config
pwsh -File D:\work\nvim-config\scripts\install.ps1
```

저장소가 private이므로 `git clone` 전에 GitHub 로그인이 필요합니다. 로그온할 때 데몬을 자동으로 시작하려면 끝에 `-Autostart`를 붙입니다.

스크립트는 여러 번 실행해도 안전하며, 다음을 수행합니다.

1. 빠진 도구 설치: neovim, neovide, git, ripgrep, fzf, fd, tree-sitter, mingw, llvm, uv (scoop), compiledb, scons (uv tool)
2. Monoplex KR Nerd Font 설치. 버전과 해시를 고정합니다.
3. 정션 2개 생성
4. `bin\`을 사용자 PATH에 추가. PowerShell 프로필은 수정하지 않습니다.
5. `lazy-lock.json` 버전으로 플러그인 설치, Mason으로 언어 서버와 포맷터 설치

**폴백 폰트는 자동으로 설치되지 않습니다.** 없으면 경고가 표시됩니다. 한자, 일본어 가나, 조합형 자모를 제대로 보려면 설치하세요.

```powershell
scoop bucket add nerd-fonts
scoop install SarasaGothic-K
```

**새 터미널을 열어** 확인합니다.

```powershell
nvd --status    # not running 이 나오면 정상
nvd             # Neovide 창이 열립니다
```

다른 PC에서 고친 내용을 받을 때는 다음과 같이 합니다.

```powershell
nvd --stop
git -C D:\work\nvim-config pull
pwsh -File D:\work\nvim-config\scripts\install.ps1
```

## 5. 사용법

### `nvd` 명령

```powershell
nvd                  # 창 열기. 데몬이 없으면 시작하고, 창이 있으면 재사용
nvd src\main.c a.py  # 파일 열기. 상대 경로는 현재 폴더 기준
nvd -- -odd-name.txt # 대시로 시작하는 파일 이름
nvd --tui            # 지금 터미널에서 데몬에 연결
nvd --status         # pid, 연결된 UI 수, 수정된 버퍼, LSP 표시
nvd --start          # 창 없이 데몬만 시작
nvd --stop           # 데몬 종료. 수정된 버퍼가 있으면 거부
nvd --stop --force   # 수정 내용을 버리고 강제 종료
nvd --restart        # 데몬 재시작 (창은 열지 않음)
nvd --help           # 도움말
```

`nvd`가 맞는 이름입니다. `nv`는 PowerShell에서 `New-Variable`의 내장 별칭이라 스크립트가 실행되지 않습니다.

### 창을 닫을 때

| 동작 | 결과 |
|---|---|
| 창의 X 버튼, 마지막 창에서 `:q` `:wq` `ZZ` `ZQ` | 창만 닫힘. 데몬과 버퍼 유지 |
| `:qa` | 데몬까지 종료. 다음 `nvd`가 새로 시작 |
| `:qa` (수정된 버퍼 있음) | 저장 여부를 물어본 뒤 종료 |
| 수정된 버퍼에서 마지막 창 `:q` | 창만 닫힘. 내용은 **디스크에 저장되지 않고** 데몬에 남음 |

> **저장하지 않은 내용은 데몬 메모리와 스왑 파일에만 있습니다.** 창을 닫아도 사라지지 않을 뿐, 파일에 저장된 것은 아닙니다. 다시 창을 열어 `:ls`로 찾고 `:wa`로 저장하세요. `nvd --status`의 `modified` 항목에서도 확인할 수 있습니다.

데몬은 PC를 다시 시작하거나 로그오프하면 함께 끝납니다. 세션 복원 기능은 없어서 열어 둔 버퍼 목록은 이어지지 않습니다.

### 여러 프로젝트

다른 폴더에서 `nvd`를 호출하면 **새 탭**이 열리고 그 탭의 작업 폴더만 바뀝니다. 같은 폴더에서 호출하면 현재 탭을 그대로 씁니다. 탭 이동은 `gt`, `gT`입니다.

완전히 분리된 데몬이 필요하면 파이프 이름을 지정합니다.

```powershell
$env:NV_PIPE = '\\.\pipe\nvim-daemon-other'
nvd
```

### 주요 키

리더 키는 `Space`입니다.

| 분류 | 키 | 기능 |
|---|---|---|
| 찾기 | `<leader>ff` / `fg` / `fb` / `fr` | 파일 / 내용 / 버퍼 / 최근 파일 |
| | `<leader>fd` / `fh` / `f.` | 진단 / 도움말 / 마지막 검색 이어서 |
| 코드 | `gd` / `gD` / `gr` | 정의 / 선언 / 참조 |
| | `K` | 호버 |
| | `<leader>rn` / `ca` / `cf` | 이름 변경 / 코드 액션 / 포맷 |
| | `<leader>xd` | 진단을 위치 목록으로 |
| 파일 | `-` | 폴더를 버퍼처럼 편집 (oil) |
| | `<leader>w` | 저장 |
| Git | `]h` / `[h` | 다음 / 이전 변경 블록 |
| | `<leader>gs` / `gr` / `gp` | 블록 스테이지 / 되돌리기 / 미리 보기 |
| | `<leader>gb` / `gd` | 라인 blame / 파일 diff |
| 창, 버퍼 | `<C-h/j/k/l>` | 창 이동 |
| | `]b` / `[b` | 다음 / 이전 버퍼 |
| Neovide | `<C-=>` / `<C-->` / `<C-0>` | 확대 / 축소 / 초기화 |

### 저장할 때 포맷

| 언어 | 포맷터 | 조건 |
|---|---|---|
| Lua | stylua | 항상 |
| Python | ruff | 항상 |
| Rust | rustfmt | 항상 |
| C, C++ | clang-format | 프로젝트에 `.clang-format`이 있을 때만 |

### SCons 프로젝트: `:CompileDb`

clangd가 헤더를 찾으려면 `compile_commands.json`이 필요합니다. 프로젝트의 C/C++ 파일을 연 상태에서 다음을 실행합니다.

```vim
:CompileDb                 " SConstruct를 위로 찾아 실행
:CompileDb debug=1 target  " 인자는 scons에 그대로 전달
```

실제 빌드는 일어나지 않고, 끝나면 clangd가 자동으로 재시작됩니다. 알아 둘 점은 다음과 같습니다.

- `scons -n`도 `SConstruct`(Python 코드)를 실행합니다. 그래서 자동으로 돌리지 않고 안내만 표시합니다. 신뢰하는 프로젝트에서 실행하세요.
- **다른 터미널에서 `scons`가 빌드 중일 때는 실행하지 마세요.** 서명 파일(`.sconsign*`)을 잠시 치우기 때문에 빌드 상태가 꼬일 수 있습니다.
- MSVC `cl`은 파싱되지 않습니다. SConstruct에서 `env.Tool('compilation_db')`와 `env.CompilationDatabase()`를 사용하세요.
- 강제 종료로 `.sconsign*.compiledb-bak` 파일이 남으면 다음 `:CompileDb`가 복구합니다.

## 6. 설정 바꾸기

저장소가 곧 설정이므로 파일을 고치고 데몬을 재시작하면 반영됩니다.

| 바꾸려는 것 | 고칠 파일 |
|---|---|
| 폰트, 글자 크기 | `lua\core\neovide.lua`의 `guifont` (`:h12`가 크기) |
| 들여쓰기 등 기본 옵션 | `lua\core\options.lua` |
| 플러그인과 무관한 키 | `lua\core\keymaps.lua` |
| 플러그인 키 | 해당 `lua\plugins\*.lua`의 `keys` |
| 언어 서버 추가 | `lua\plugins\lsp.lua` |
| 구문 분석 언어 추가 | `lua\plugins\treesitter.lua` |
| 포맷터 | `lua\plugins\conform.lua` |
| 새 기능 | `lua\plugins\<기능>.lua` 파일 추가 |

**반영 방법:** 데몬은 시작할 때 설정을 한 번만 읽으므로 재시작이 필요합니다. 재시작하면 창이 닫히고 열린 버퍼도 사라지므로 먼저 저장하세요.

```powershell
nvd --restart   # 수정된 버퍼가 있으면 거부합니다
nvd
```

환경 변수(PATH 등)도 데몬 시작 시점에 고정되므로, 툴체인을 새로 설치했다면 같은 방법으로 재시작합니다.

**폰트를 바꿀 때**는 폰트의 실제 폭을 먼저 확인하세요. 한글이 영문의 정확히 2배 폭이 아니면 격자가 어긋납니다. 기준과 측정 결과는 README의 폰트 절에 있습니다.

### 플러그인 추가와 되돌리기

```powershell
# 추가: 파일 하나를 만들고 시험합니다
#   lua\plugins\<기능>.lua
# 마음에 안 들면: 그 파일을 지우고 Neovim에서 :Lazy clean 실행, 그다음
git -C D:\work\nvim-config checkout .

# :Lazy update 후 문제가 생기면: 버전 파일을 되돌린 뒤 Neovim에서 :Lazy restore 실행
git -C D:\work\nvim-config checkout lazy-lock.json
```

`git checkout .`은 커밋하지 않은 **모든** 변경을 버립니다. 실행 전에 `git status`로 확인하세요. 고친 내용은 저장소에서 커밋하고 푸시해 두면 다른 PC로 옮길 수 있습니다.

## 7. 문제 해결

| 증상 | 원인과 해결 |
|---|---|
| `nvd`를 찾을 수 없음 | PATH는 새로 시작한 프로그램에만 반영됩니다. 터미널을 새로 여세요. 터미널을 띄운 앱(IDE, 터미널 관리자 등)이 설치 전부터 실행 중이었다면 그 앱도 다시 시작해야 합니다 |
| `daemon is not responding` | 데몬이 스왑 파일 질문 등에서 입력을 기다리는 상태입니다. 창에서 답하거나 `nvd --stop --force`로 종료합니다. 강제 종료는 수정 내용을 버립니다 |
| `modified buffers, use --force` | 저장하지 않은 버퍼가 있습니다. `nvd`로 창을 열어 `:wa`로 저장한 뒤 다시 실행합니다 |
| 파일을 열 때 스왑 파일 경고 | 이전 데몬이 비정상 종료된 경우입니다. 복구(`R`) 또는 삭제(`D`)를 선택합니다 |
| 툴체인을 설치했는데 찾지 못함 | `nvd --restart`로 데몬의 환경을 새로 고칩니다 |
| 글자 간격이 이상하거나 네모로 보임 | Windows 설정의 글꼴 목록에서 `Monoplex KR Nerd Font`와 `Sarasa Fixed K`를 확인합니다 |
| 노멀 모드 키가 한글로 입력됨 | IME는 입력 모드와 검색에서만 켜지도록 `lua\core\neovide.lua`에 설정되어 있습니다. 그래도 증상이 있으면 이 파일의 IME 부분을 확인합니다. 이 동작은 아직 화면에서 확인하지 못했습니다 (9절) |
| Neovide 창이 아주 작게 열림 | `tests\daemon.ps1` 같은 테스트가 창 크기를 500×500으로 저장한 경우입니다. `%LOCALAPPDATA%\neovide\neovide-settings.json`을 지웁니다 |
| 설치 시 `already exists and is not a link` | 기존 설정 폴더가 있습니다. 옮긴 뒤 다시 실행합니다 |
| `:CompileDb`가 `no compile commands` 표시 | 메시지의 안내를 따릅니다. MSVC이거나 `SConsignFile`을 프로젝트 밖에 둔 경우입니다 |
| 플러그인이나 언어 서버가 없음 | `nvd --stop` 후 `install.ps1`을 다시 실행합니다 |

상태를 자세히 볼 때는 Neovim 안에서 `:checkhealth`, `:Lazy`, `:Mason`, `:ConformInfo`를 사용합니다. 로그는 `%LOCALAPPDATA%\nvim-data`의 `nvim.log`, `lsp.log`, `mason.log`에 있습니다.

## 8. 제거

```powershell
nvd --stop
pwsh -File D:\work\nvim-config\scripts\install.ps1 -Uninstall
```

정션, PATH 항목, 시작프로그램 바로가기만 제거합니다. 저장소, `nvim-data`, scoop 도구, 폰트는 남으므로 필요 없으면 직접 지웁니다. 폰트는 Windows 설정의 글꼴 메뉴에서 제거합니다.

## 9. 검증 상태 (2026-11-06)

`tests\smoke.lua`와 `tests\daemon.ps1`이 모두 통과한 상태입니다. 다음과 같이 실행합니다. `tests\daemon.ps1`은 실제 Neovide 창을 띄우며 전용 파이프를 쓰므로 평소 데몬에는 영향을 주지 않지만, 창 크기 파일은 덮어쓸 수 있습니다.

```powershell
cd D:\work\nvim-config
nvim --headless -c "luafile tests/smoke.lua"
pwsh -File tests/daemon.ps1
```

**자동 테스트로 확인한 것:** 데몬 시작과 유지, 창 연결과 분리, 재연결, 한글/공백/작은따옴표 경로, 탭별 작업 폴더, `:q`와 `:qa` 동작, 수정된 버퍼 보호, `:CompileDb`와 clangd 연동, 인코딩 판별, 포맷.

**아직 확인하지 못한 것:**

- Neovide 화면에서 폰트가 실제로 어떻게 보이는지 (로그의 폰트 로드와 칸 크기까지만 확인)
- 창이 앞으로 오는 동작, 한글 입력(IME) 전환
- fzf-lua 검색 창, blink.cmp 자동완성 팝업, gitsigns와 oil의 실제 조작 (플러그인 로드까지만 확인)
- 새 PC나 scoop이 없는 환경에서의 설치, `install.ps1`의 `-Autostart`와 `-Uninstall`

문제를 발견하면 이 절을 갱신해 주세요.

## 10. LLM 에이전트 규칙 문서

앞으로 기능을 추가할 때 LLM 에이전트가 따를 규칙과 기억할 점은 **`AGENT.md` 한 파일**에 있습니다. 기능 추가 절차, 파일 배치, 데몬과 폰트 규칙, 플러그인 선정 기준, 이전에 겪은 함정이 담겨 있습니다.

### 저장 위치

| 파일 | 위치 | 역할 |
|---|---|---|
| `AGENT.md` | 저장소 루트 (`D:\work\nvim-config\AGENT.md`) | **규칙 원본.** 규칙은 여기에만 씁니다 |
| `CLAUDE.md` | 저장소 루트 | Claude Code가 자동으로 읽는 파일. `AGENT.md`를 불러옵니다 |
| `AGENTS.md` | 저장소 루트 | Codex 등이 찾는 파일. `AGENT.md`를 읽으라고 안내합니다 |
| `GEMINI.md` | 저장소 루트 | Gemini CLI가 찾는 파일. `AGENT.md`를 불러옵니다 |

저장소가 곧 Neovim 설정 폴더이므로 `%LOCALAPPDATA%\nvim\AGENT.md`도 같은 파일입니다. Neovim은 이 문서들을 설정으로 읽지 않으므로 동작에 영향을 주지 않습니다.

**지켜야 할 것:**

- **파일 이름과 위치를 바꾸지 마세요.** 에이전트는 시작 폴더 또는 작업 파일이 있는 폴더에서 정해진 이름의 파일을 찾습니다.
- **규칙을 진입 파일에 복사하지 마세요.** 복사본은 언젠가 원본과 달라집니다.
- **`nvim-data`나 `~\.claude`에 두지 마세요.** git에 남지 않아 다른 PC로 옮겨지지 않습니다.
- **고친 뒤에는 커밋하고 푸시하세요.** 다른 PC의 에이전트도 같은 규칙을 쓰게 하려면 필요합니다.

### 실제로 읽히는지 시험한 결과 (2026-11-06)

`AGENT.md`에 임시 표식을 넣고, 각 에이전트에게 파일을 직접 찾으라는 말 없이 표식 값을 물었습니다. 시험 후 표식은 지웠습니다.

| 에이전트 | 시작 위치 | 결과 |
|---|---|---|
| Claude Code | 저장소 폴더 | 자동으로 읽음 |
| Claude Code | `%LOCALAPPDATA%\nvim` | 자동으로 읽음 |
| Claude Code | 상위 폴더 `D:\work` | 저장소 파일(`init.lua`)을 읽는 순간 함께 읽음 |
| Claude Code | 관계없는 빈 폴더 (대조군) | 읽지 않음 (정상) |
| agy | 저장소 폴더 | 찾아냄. 다만 프로젝트 지침을 따르라고 지시한 시험이라 자동으로 읽는지는 알 수 없음 |
| Codex | 저장소 폴더 | **미확인.** 이 PC에 로그인되어 있지 않아 실행 실패 (401) |
| Gemini CLI | 저장소 폴더 | **미확인.** 3분 넘게 응답이 없어 중단 |

### 한계

이 파일들은 에이전트가 **읽게 할 뿐, 규칙을 지키도록 강제하지는 못합니다.** 빠뜨리지 않으려면 다음을 권합니다.

- 에이전트는 저장소 폴더에서 시작합니다. 상위 폴더에서 시작하면 저장소 파일을 읽기 전까지는 규칙을 모릅니다.
- 미확인 에이전트를 쓸 때는 "AGENT.md를 읽고 따라 줘"라고 처음에 말합니다.
- 결과를 받으면 `docs/CUSTOMIZATIONS.md`가 같은 커밋에서 갱신됐는지 봅니다. 규칙이 지켜졌는지 가장 쉽게 확인하는 방법입니다.
