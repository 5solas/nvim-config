# 개발 기록

이 저장소를 만든 대화(2026-11-06, 사용자와 Claude Code)를 정리한 문서입니다. 무엇을 요청했고, 왜 이렇게 정했으며, 무엇이 잘못됐고, 무엇을 확인하지 못했는지 남깁니다.

사용법은 [사용자 안내서](USER_GUIDE.md), 달라진 설정 목록은 [기본값 대비 추가 내역](CUSTOMIZATIONS.md), 에이전트 규칙은 [AGENT.md](../AGENT.md)를 보세요.

**개발 환경:** Windows 11, PowerShell 7.6, Neovim 0.12.6, Neovide 0.16.2, compiledb 0.10.7, SCons 4.11.1

## 1. 요청과 결과

| 순서 | 요청 | 결과 |
|---|---|---|
| 1 | GitHub `5solas` 계정에 저장소를 만들 수 있는지 | 가능. `gh`가 `repo` 권한으로 로그인되어 있음을 확인 |
| 2 | Neovim + Neovide 설정 생성. 헤드리스 파이프 데몬과 Neovide 클라이언트, PowerShell에서 쉽게 호출, 참고 자료 반영 | `D:\work\nvim-config` 생성. 데몬과 `nvd` 명령 구현 |
| 3 | compiledb를 찾아 Neovim에 연동 | `:CompileDb` 구현. Windows 문제 3가지 보정 |
| 4 | git 저장소를 만들고 개발 후 GitHub에 푸시 | [5solas/nvim-config](https://github.com/5solas/nvim-config). 공개 범위를 지정받지 않아 private으로 생성 |
| 5 | 한글과 코딩용 폰트 처리를 넓게 분석해 설정 | Monoplex KR Nerd Font + Sarasa Fixed K. 폰트 파일을 직접 측정해 결정 |
| 6 | 취지, 목표, 사용법, 파일 위치를 담은 사용자 문서 | `docs/USER_GUIDE.md` |
| 7 | 기본 설정에서 추가한 내용의 문서화 | `docs/CUSTOMIZATIONS.md`. 항목마다 출처 표시 |
| 8 | 에이전트가 항상 참고할 규칙 문서와 그 저장 위치 문서화 | `AGENT.md` 보강, 진입 파일 3개, 안내서 10절. 실제로 읽히는지 시험 |
| 9 | 대화 내용을 종합해 푸시 | 이 문서 |

### 참고 자료에서 그대로 따른 것

처음 받은 "모듈형 점진적 구축 방법론"에서 다음을 반영했습니다.

- 1파일 1기능 구조(`lua/plugins/`), `AGENT.md`로 LLM 컨텍스트 고정
- kickstart.nvim과 LazyVim을 플러그인 기준으로 삼기, 구형 플러그인 금지
- 표준 스택: lazy.nvim, fzf-lua, blink.cmp, 내장 LSP + nvim-lspconfig + mason, conform.nvim, oil.nvim, gitsigns.nvim
- 빈 `.gitignore`, `lazy-lock.json` 추적, 단계별 커밋, 롤백 절차
- 인코딩 `ucs-bom,utf-8,cp949,euc-kr,latin1`, 시작 시간 30 ms 목표, `gd`와 `gr`, 저장 시 포맷

### 참고 자료와 달라진 것

| 자료 | 실제 | 이유 |
|---|---|---|
| `%LOCALAPPDATA%\nvim`이 git 루트 | `D:\work\nvim-config`가 루트, 표준 위치는 정션 | `d:/work`에 폴더를 만들라는 요청 |
| 대상 Neovim 0.10+ / 0.11+ | 0.12+ | 설치된 버전 기준 |
| 시작 시간 30 ms 이내 | 설정이 더하는 몫 약 30 ms, 전체 약 100 ms | `nvim --clean`만으로 약 70 ms 소요 |
| nvim-treesitter 사용 (브랜치 언급 없음) | `main` 브랜치 | 현재 표준. tree-sitter CLI와 C 컴파일러 필요, 지연 로드 불가 |
| 언어 서버 pyright, ruff, rust-analyzer, lua_ls | clangd 추가 | compiledb 연동에 필요 |

## 2. 주요 결정과 이유

| 결정 | 이유 |
|---|---|
| 데몬 통신에 `nvim -l` + RPC 사용 | `--remote-expr`는 출력을 캡처하면 결과 대신 TUI 이스케이프 코드를 돌려줌 |
| 창 분리에 UI 채널 `chanclose` 사용 | `:q` 직후 `:detach`는 서버를 멈추게 함 (0.12.6, Windows) |
| 다른 폴더에서 호출하면 새 탭 + `tcd` | 다른 프로젝트 탭의 작업 폴더를 건드리지 않기 위해 |
| 데몬에 플러그인 미리 로드 | 창을 열 때 대기 시간을 없애는 것이 데몬의 목적 |
| Mason 자동 설치 끔 | 데몬 시작이 네트워크에 묶이지 않게 |
| `:CompileDb` 자동 실행 안 함 | `scons -n`도 SConstruct(Python)를 실행하므로 안내만 표시 |
| C/C++는 `.clang-format`이 있을 때만 포맷 | 규칙 없는 기존 코드가 통째로 재정렬되는 것을 방지 |
| 설치 스크립트는 기존 폴더를 덮어쓰지 않음 | 사용자 설정 보호. 다시 실행해도 안전 |
| PowerShell 프로필 수정 안 함 | PATH만으로 충분하고 프로필은 사용자 영역 |
| 규칙 원본을 `AGENT.md` 하나로 유지 | 에이전트별 파일에 복사하면 내용이 어긋남 |

### 폰트 결정

리뷰 글은 Neovim 격자 기준의 차이를 알려 주지 않아 폰트 파일의 글자 폭을 fontTools로 직접 쟀습니다. 후보별 수치는 README의 폰트 절에 있습니다.

- **채택:** Monoplex KR Nerd Font. 한글:영문 2.00, 글자가 자연스럽게 채워지고 Nerd 아이콘 내장, 굵기당 4.7 MB
- **폴백:** Sarasa Fixed K. 한자, 가나, 조합형 자모 담당
- **제외:**
  - D2Coding Nerd Font Mono: 한글 폭 비율 1.00
  - Sarasa Mono K: `… — → ①`이 2칸
  - JetBrains 계열, Yeomil: 1.2em 슬롯에서 한글이 벌어짐
  - D2Coding 1.4.0: 행이 빠듯하고 `|`가 `¦`처럼 보임

### 측정값

| 항목 | 값 |
|---|---|
| `nvd.cmd`로 데몬 시작 | 약 750~890 ms |
| 창 연결 | 약 360~440 ms |
| Neovim 시작 | `--clean` 약 70 ms, 설정 포함 약 100 ms |
| Neovide 격자 칸 | 8.448 × 21 px (0.528em × 16 px, 19 + 2 px와 일치) |

## 3. 겪은 문제와 해결

| 문제 | 원인 | 해결 |
|---|---|---|
| `nv` 명령이 실행되지 않음 | PowerShell에서 `nv`는 `New-Variable` 내장 별칭. 테스트가 경로로만 호출해 놓침 | `nvd`로 이름 변경, 이름으로 호출하는 테스트 추가 |
| `:q` 후 데몬이 멈춤 | `:q` 직후 `:detach` | `chanclose`로 교체 |
| 수정된 버퍼의 `:qa`에서 질문 중 창이 사라짐 | 예약된 분리가 질문 상태에서도 실행됨 | 질문 모드(`r?`)면 분리를 건너뜀, 회귀 테스트 추가 |
| 스왑 질문에 걸린 데몬 때문에 `nvd`가 멈춤 | RPC 응답 대기에 제한 없음 | 5초 제한, 종료 코드 3과 안내 메시지 |
| `:qa` 직후 `nvd` 실패 | 파이프는 보이는데 연결은 거부되는 순간이 있음 | 재시도 처리 |
| compiledb 결과가 `[]` | `gcc.exe`가 정규식에 안 맞고 `src\foo.c`의 `\f`가 폼피드로 해석됨 | 파싱 전 로그 정규화 |
| 인자의 한글이 깨짐 | compiledb의 잘못된 해석 | 파싱 후 `vim.iconv`로 복원 |
| 빌드 후 `scons -n`이 명령을 출력 안 함 | `.sconsign*`으로 최신 상태 판단 | 잠시 치웠다 복원. 바이트 단위 동일, 재빌드 없음 |
| C 파일 저장마다 포맷터 경고 | `.clang-format`이 없을 때의 conform 알림 | `notify_no_formatters = false` |
| conform이 clang-format을 찾지 못함 | 이름을 `clang_format`으로 적음 | `clang-format`으로 수정 |
| 설정이 더하는 시작 시간이 약 41 ms로 증가 | lazy spec 평가 시점의 `executable("clangd")` | `config` 안으로 이동, 약 30 ms로 복귀 |
| `Set-Location`으로 셸 위치가 `work-kb-nvim`으로 이동 | 작업 위치가 다음 명령까지 유지됨 | `D:\work`로 복귀. 그 폴더는 변경하지 않음 |

같은 함정을 반복하지 않도록 주요 항목을 `AGENT.md`의 "Things to Remember"에 옮겨 두었습니다.

## 4. 이 PC에서 바꾼 것

- **정션:** `%LOCALAPPDATA%\nvim`, `%APPDATA%\neovide`
- **사용자 PATH:** `D:\work\nvim-config\bin` 추가
- **도구:** `scoop install tree-sitter`, `uv tool install compiledb scons`
- **폰트:** Monoplex KR Nerd Font 4종을 사용자 범위로 설치
- **데이터:** `%LOCALAPPDATA%\nvim-data`에 플러그인과 Mason 도구 설치
- **삭제:** 테스트가 500×500으로 덮어쓴 `%LOCALAPPDATA%\neovide\neovide-settings.json`. 대화 중 두 번 지웠으며, 그 전에 저장된 창 크기가 있었다면 사라졌습니다.

PowerShell 프로필은 수정하지 않았습니다. 다른 세션이 실행하던 `work-kb` 테스트 프로세스도 건드리지 않았습니다.

## 5. 검증 결과

**통과한 것:**

- `tests/smoke.lua`와 `tests/daemon.ps1`(49개 항목) 모두 통과. 기준은 커밋 `7cbe313`이며, 그 뒤로는 문서만 바뀌었습니다.
- 수정된 버퍼에서 마지막 창 `:q`: 창만 닫히고, 디스크는 그대로이며, 내용은 데몬에 남고, `nvd --stop`이 거부함 (전용 파이프로 시험)
- `nvd --tui`로 WezTerm에서 연결과 `:q` 후 데몬 유지. **이름을 `nvd`로 바꾸기 전에 확인했습니다.**
- 새 clone에서 빈 `.gitignore`와 CRLF `.cmd` 확인. **역시 이름 변경 전입니다.**
- Neovide 로그에서 Monoplex 로드와 격자 칸 크기 확인

**에이전트 규칙 읽기 시험:** `AGENT.md`에 임시 표식을 넣어 시험했으며, 결과는 [안내서 10절](USER_GUIDE.md#10-llm-에이전트-규칙-문서)에 있습니다. Claude Code는 확인됐고, agy는 지시했을 때 찾아냈으며, Codex와 Gemini CLI는 미확인입니다.

**확인하지 못한 것:**

- Neovide 화면의 실제 모습. 시험 당시 PC가 잠금 화면이었습니다.
- 창이 앞으로 오는 동작, 한글 입력(IME) 전환
- fzf-lua 검색 창, blink.cmp 자동완성 팝업, gitsigns와 oil의 실제 조작. 플러그인 로드까지만 확인했습니다.
- 새 PC나 scoop 없는 환경의 설치, `install.ps1 -Autostart`, `-Uninstall`. `-Uninstall`을 쓰는 저장소 이동 절차도 여기에 해당합니다.

## 6. 대화 중 정정한 보고

- **`-Uninstall` 미검증 누락:** 처음 보고에서 되돌리기 방법으로 안내하면서 실행해 보지 않았다는 점을 빠뜨렸습니다. 이후 정정했습니다.
- **Neovide `tabs` 설명 오류:** 초안에 "Neovim 탭을 Neovide 탭으로 바꾸지 않음"이라고 적었으나 틀렸습니다. 공식 문서 기준으로 "Neovide에 직접 넘긴 파일을 탭으로 열지 않음"입니다. 푸시 전에 고쳤습니다.
- **창 크기 파일 덮어쓰기:** 문서 확인용 시험이 창 크기 파일을 덮어쓴 것을 수정 시각으로 발견해 지우고 보고했습니다.

## 7. 남은 일

필수 작업은 없습니다. 아래는 확인하거나 정하면 좋은 항목입니다.

- [ ] 잠금 해제 후 Neovide에서 폰트, IME, 자동완성, 검색 창을 직접 확인
- [ ] 필요하면 `install.ps1 -Autostart`로 로그온 자동 시작 설정 (미시험)
- [ ] `tests/daemon.ps1`이 창 크기 파일을 덮어쓰지 않도록 개선 (지금은 `AGENT.md`에 주의 사항으로만 기록)
- [ ] `work-kb-nvim`의 설치 스크립트가 이 저장소의 정션을 덮어쓰지 않도록 조율. 두 설정은 기본 폰트도 다릅니다.
- [ ] Codex를 쓸 계획이면 로그인 후 규칙 읽기 재시험, Gemini CLI도 응답 없음 원인 확인 후 재시험

## 8. 커밋 기록

| 커밋 | 내용 |
|---|---|
| `a57a2b0` | 코어 옵션과 lazy 부트스트랩 |
| `16d47f9` | 테마, treesitter, fzf-lua |
| `e5f74d3` | 내장 LSP, mason, blink.cmp, conform |
| `5aeca95` | gitsigns, oil |
| `e267fbd` | `:CompileDb` |
| `58a64ea` | clangd 확인 위치 이동 (시작 시간) |
| `9887008` | 파이프 데몬, Neovide 클라이언트, 한글 폰트 |
| `d4e792e` | README와 폰트 규칙 |
| `7cbe313` | `nv`를 `nvd`로 이름 변경 |
| `1d23f30` | 사용자 안내서 |
| `2728743` | 기본값 대비 추가 내역 |
| `1d33722` | 에이전트 규칙 보강과 진입 파일 |

## 9. 참고한 자료

**compiledb와 SCons:** [compiledb](https://github.com/nickdiego/compiledb), [scons-compiledb](https://github.com/pinetr2e/scons-compiledb), [scons-compiledb PyPI](https://pypi.org/project/scons-compiledb/0.5.3/), [scons-compilation-db](https://github.com/exg/scons-compilation-db)

**폰트:** [Monoplex](https://github.com/y-kim/monoplex), [Sarasa Gothic](https://github.com/be5invis/Sarasa-Gothic), [D2Coding](https://naver.github.io/d2-coding-font/), [JetBrainsMonoHangul](https://github.com/Jhyub/JetBrainsMonoHangul), [JetKaiMono](https://github.com/phyyou/JetKaiMono), [Yeomil Mono](https://github.com/taevel02/yeomil-mono), [Yeomil Mono 소개](https://braindetox.kr/en/posts/yeomil_mono_coding_font_2026.html), [기계인간 John Grib: 코딩 폰트](https://johngrib.github.io/wiki/coding-font/), [한글 고정폭 폰트 4선](https://designnews.kr/collections/coding-monospace-fonts), [폭스씨지: 코딩용 고정폭 폰트](https://foxcg.com/developer-coding-fonts/), [musl 메일링 리스트 논의](https://openwall.com/lists/musl/2021/12/27/9)

**Neovide:** [설정](https://neovide.dev/configuration.html), [설정 파일](https://neovide.dev/config-file.html), [명령줄 옵션](https://neovide.dev/command-line-reference.html), [폴백 폰트 논의 #1952](https://github.com/neovide/neovide/discussions/1952), [이슈 #2240](https://github.com/neovide/neovide/issues/2240)
