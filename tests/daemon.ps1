#requires -Version 7
# 실제 Neovide 창을 띄워 nv를 검증한다 (창이 잠깐 나타난다). 전용 파이프를 쓰므로 평소 데몬과 충돌하지 않는다.
#   pwsh -File tests/daemon.ps1 [-Screenshot <png path>]
param([string]$Screenshot)

$ErrorActionPreference = 'Stop'
$env:NV_PIPE = "\\.\pipe\nvim-daemon-test-$PID"
$nv = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin\nv.ps1'
$nvCmd = [IO.Path]::ChangeExtension($nv, '.cmd')
$script:failed = 0

function Check([string]$Name, $Ok, $Detail) {
    if ($Ok) { "ok   $Name" }
    else { "FAIL $Name -- $Detail"; $script:failed++ }
}
$rpc = Join-Path (Split-Path -Parent $nv) 'nv-rpc.lua'
function Rpc([string]$Code, [string]$Value) {
    $saved = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    try { (& nvim -l $rpc $env:NV_PIPE $Code $Value) -join "`n" }
    finally { [Console]::OutputEncoding = $saved }
}
function Expr([string]$E) { Rpc 'return tostring(vim.fn.eval(...))' $E }
function Send([string]$Keys) { Rpc 'vim.api.nvim_input(...)' $Keys | Out-Null }
function Status { Rpc "return require('core.daemon').status()" | ConvertFrom-Json }
function Neovides {
    @(Get-CimInstance Win32_Process -Filter "Name='neovide.exe'" | Where-Object { $_.CommandLine -like "*$($env:NV_PIPE)*" })
}
function WaitFor([scriptblock]$Cond, [int]$Ms = 8000) {
    $c = [Diagnostics.Stopwatch]::StartNew()
    while ($c.ElapsedMilliseconds -lt $Ms) {
        if (& $Cond) { return $true }
        Start-Sleep -Milliseconds 50
    }
    return $false
}

$work = Join-Path ([IO.Path]::GetTempPath()) "nv-test-$PID"
$dirA = Join-Path $work "한글 경로's"
$dirB = Join-Path $work 'other'
New-Item -ItemType Directory $dirA, $dirB | Out-Null
$fileA = Join-Path $dirA '문서 a.lua'
$fileB = Join-Path $dirA 'b.c'
$fileC = Join-Path $dirB 'c.py'
'print("한글")' | Set-Content $fileA
'int main(void) { return 0; }' | Set-Content $fileB
'x = 1' | Set-Content $fileC
$bufName = "bufname('%')"

try {
    Check 'status before start' ((& $nv --status) -eq 'not running') (& $nv --status)

    # cmd.exe 경유: 시작한 프로세스가 끝나도 데몬이 살아 있어야 한다
    $c = [Diagnostics.Stopwatch]::StartNew()
    cmd /c "`"$nvCmd`" --start"
    "info daemon start via nv.cmd: $($c.ElapsedMilliseconds) ms"
    $s = Status
    Check 'daemon survives the starting shell' ($s.pid -gt 0) $s
    Check 'daemon has no UI' ($s.uis -eq 0) $s.uis
    $hidden = (Get-Process -Id $s.pid).MainWindowHandle
    Check 'daemon has no visible window' ($hidden -eq 0) $hidden
    $loaded = "local s = require('lazy').stats(); return s.loaded .. '/' .. s.count"
    Check 'plugins preloaded' (WaitFor { $n, $total = (Rpc $loaded) -split '/'; $n -eq $total }) (Rpc $loaded)

    # 첫 열기: Neovide 생성, 한글·공백·작은따옴표 경로
    Push-Location $dirA
    $c.Restart()
    & $nv $fileA
    $attached = WaitFor { (Status).neovide }
    "info window attached after: $($c.ElapsedMilliseconds) ms"
    Check 'neovide attaches through the pipe' $attached (Status)
    Check 'file with korean, space and quote opens' (WaitFor { (Expr $bufName) -like '*문서 a.lua' }) (Expr $bufName)
    Check 'korean content decoded' ((Expr "getline(1)") -eq 'print("한글")') (Expr "getline(1)")
    Check 'tab cwd follows the caller' ((Expr "getcwd()") -like '*other*' -or (Expr "getcwd()") -like "*한글 경로*") (Expr "getcwd()")
    Check 'guifont set on the server' ((Expr "&guifont") -like 'Monoplex KR Nerd Font,*') (Expr "&guifont")
    Check 'circled digit is 2 cells in the daemon grid' ((Expr "strwidth('①')") -eq '2') (Expr "strwidth('①')")
    Check 'hangul is 2 cells' ((Expr "strwidth('한')") -eq '2') (Expr "strwidth('한')")
    Check 'ellipsis stays 1 cell' ((Expr "strwidth('…')") -eq '1') (Expr "strwidth('…')")
    Check 'neovide variable set after attach' ((Rpc 'return tostring(vim.g.neovide)') -eq 'true') (Rpc 'return tostring(vim.g.neovide)')

    if ($Screenshot) {
        Start-Sleep -Seconds 2
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = [Drawing.Bitmap]::new($b.Width, $b.Height)
        [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
        $bmp.Save($Screenshot)
    }

    # 재사용: 같은 폴더의 두 번째 파일은 창을 늘리지 않는다
    & $nv $fileB
    Check 'second file opens in the same window' (WaitFor { (Expr $bufName) -like '*b.c' }) (Expr $bufName)
    Start-Sleep -Milliseconds 300
    Check 'only one neovide' ((Neovides).Count -eq 1) (Neovides).Count
    Check 'same tab when cwd matches' ((Expr "tabpagenr('$')") -eq '1') (Expr "tabpagenr('$')")
    Pop-Location

    # 다른 폴더: 새 탭, 탭 단위 cwd
    Push-Location $dirB
    & $nv 'c.py'
    Check 'relative path resolved against the caller' (WaitFor { (Expr $bufName) -like '*c.py' }) (Expr $bufName)
    Check 'other project gets a new tab' ((Expr "tabpagenr('$')") -eq '2') (Expr "tabpagenr('$')")
    Check 'tcd applied' ((Expr "getcwd()") -like '*other') (Expr "getcwd()")
    Pop-Location

    # 창을 닫아도 데몬과 버퍼는 남는다
    $pidBefore = (Status).pid
    Get-Process -Id (Neovides)[0].ProcessId | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Check 'closing the window detaches' (WaitFor { (Status).uis -eq 0 }) (Status)
    Check 'neovide process gone' (WaitFor { (Neovides).Count -eq 0 }) (Neovides).Count
    $s = Status
    Check 'daemon survives window close' ($s.pid -eq $pidBefore) $s
    Check 'buffers survive window close' ($s.buffers -ge 3) $s.buffers

    # 다시 열면 상태 그대로
    Push-Location $dirB
    & $nv
    Check 'reattach' (WaitFor { (Status).neovide }) (Status)
    Check 'reattach keeps tabs' ((Expr "tabpagenr('$')") -eq '2') (Expr "tabpagenr('$')")
    Pop-Location

    # 마지막 창의 :q는 분리만 한다
    Send '<C-\><C-n>:tabonly<CR>:only<CR>'
    Start-Sleep -Milliseconds 300
    Check 'prepared one window' ((Expr "winnr('$')") -eq '1') (Expr "winnr('$')")
    Send '<C-\><C-n>:q<CR>'
    Check ':q on the last window detaches' (WaitFor { (Status).uis -eq 0 }) (Status)
    Check ':q keeps the daemon' ((Status).pid -eq $pidBefore) (Status).pid

    # 수정된 버퍼가 있으면 --stop 거부
    & $nv | Out-Null
    Check 'attach for edit test' (WaitFor { (Status).neovide }) ''
    Send '<C-\><C-n>iedited<Esc>'
    Check 'buffer is modified' (WaitFor { (Status).modified.Count -gt 0 }) (Status)
    $refused = $false
    try { & $nv --stop } catch { $refused = $_.Exception.Message -like '*modified*' }
    Check '--stop refuses modified buffers' $refused ''
    Check 'daemon still alive after refusal' ((Status).pid -eq $pidBefore) ''

    # --restart --force, 그 뒤 :qa는 진짜 종료
    & $nv --restart --force
    $s = Status
    Check '--restart --force gives a new daemon' ($s.pid -ne $pidBefore) $s.pid
    Check 'neovide leaves with the killed daemon' (WaitFor { (Neovides).Count -eq 0 }) (Neovides).Count
    # 수정된 버퍼의 :qa: 저장 질문에 답할 UI가 남아 있어야 한다
    & $nv | Out-Null
    Check 'attach for modified :qa test' (WaitFor { (Status).neovide }) ''
    Send '<C-\><C-n>iedited<Esc>'
    Check 'buffer modified before :qa' (WaitFor { (Status).modified.Count -gt 0 }) ''
    Send ':qa<CR>'
    $mode = "return vim.api.nvim_get_mode().mode"
    Check ':qa on modified buffer asks' (WaitFor { (Rpc $mode) -like 'r*' } 3000) (Rpc $mode)
    Start-Sleep -Milliseconds 300
    Check 'ui stays attached during the question' ((Rpc 'return #vim.api.nvim_list_uis()') -eq '1') (Rpc 'return #vim.api.nvim_list_uis()')
    Send 'n'
    Check 'answering no stops the daemon' (WaitFor { (& $nv --status) -eq 'not running' }) ''
    Check 'neovide leaves after the answer' (WaitFor { (Neovides).Count -eq 0 }) (Neovides).Count

    & $nv | Out-Null
    Check 'attach for :qa test' (WaitFor { (Status).neovide }) ''
    Send '<C-\><C-n>:qa<CR>'
    Check ':qa stops the daemon' (WaitFor { (& $nv --status) -eq 'not running' }) ''
    Check 'neovide leaves after :qa' (WaitFor { (Neovides).Count -eq 0 }) (Neovides).Count

    # 멈춘 뒤 다음 nv가 자동으로 다시 띄운다
    Push-Location $dirB
    & $nv
    Check 'nv restarts a stopped daemon' (WaitFor { (Status).neovide }) ''
    Pop-Location
    & $nv --stop --force
    Check '--stop --force' ((& $nv --status) -eq 'not running') ''
}
finally {
    Set-Location $HOME
    try { & $nv --stop --force } catch {}
    Neovides | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:failed) { "$script:failed FAILED"; exit 1 }
'ALL PASSED'
