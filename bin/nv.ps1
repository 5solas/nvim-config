#requires -Version 7
# Neovim 헤드리스 파이프 데몬 + Neovide 클라이언트. 사용법은 nv --help.
# 사용자 세션 안에서 실행될 수 있으므로 세션 상태를 바꾸지 않는다.

$ErrorActionPreference = 'Stop'
# NV_PIPE로 다른 파이프를 지정하면 서로 독립된 데몬을 띄울 수 있다
$Pipe = $env:NV_PIPE ?? "\\.\pipe\nvim-daemon-$env:USERNAME"

function Show-Help {
    @'
nv [paths...]        Open in Neovide. Starts the daemon if needed; reuses an open window.
nv --tui             Attach to the daemon in this terminal.
nv --status          Show daemon state.
nv --start           Start the daemon without opening a window.
nv --stop [--force]  Stop the daemon. Refuses if buffers are modified, unless --force
                     (which also kills a hung daemon).
nv --restart [--force]
nv --help
Use -- before a path that starts with a dash.
'@
}

# scoop shim 뒤의 실제 exe를 찾는다. 숨김 데몬과 창 프로세스를 shim 없이 직접 띄우기 위해서다.
function Resolve-Exe([string]$Name) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { throw "$Name is not on PATH" }
    $shim = [IO.Path]::ChangeExtension($cmd.Source, '.shim')
    if (Test-Path -LiteralPath $shim) {
        $line = Get-Content -LiteralPath $shim | Where-Object { $_ -match '^\s*path\s*=' } | Select-Object -First 1
        if ($line) {
            $real = ($line -split '=', 2)[1].Trim().Trim('"')
            if (Test-Path -LiteralPath $real) { return $real }
        }
    }
    return $cmd.Source
}

function Test-Daemon {
    # 파이프에 연결하지 않고 이름만 확인한다
    return [IO.Directory]::GetFiles('\\.\pipe\') -contains $Pipe
}

function Wait-Pipe([bool]$Present, [int]$TimeoutMs = 15000) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ((Test-Daemon) -ne $Present) {
        if ($clock.ElapsedMilliseconds -gt $TimeoutMs) { return $false }
        Start-Sleep -Milliseconds 20
    }
    return $true
}

function Start-Daemon {
    if (Test-Daemon) { return }
    Start-Process -FilePath (Resolve-Exe 'nvim') -WindowStyle Hidden -WorkingDirectory $HOME `
        -ArgumentList '--headless', '--listen', $Pipe, '--cmd', '"let g:nvim_daemon=1"'
    if (-not (Wait-Pipe $true)) { throw "daemon did not create $Pipe" }
}

function Invoke-Remote([string]$Function, [string]$Value) {
    # 한글 경로가 깨지지 않도록 호출 동안만 콘솔 인코딩을 UTF-8로 둔다
    $saved = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    try {
        $code = "return require('core.daemon').$Function(...)"
        $out = & (Resolve-Exe 'nvim') -l (Join-Path $PSScriptRoot 'nv-rpc.lua') $Pipe $code $Value
        if ($LASTEXITCODE -eq 3) {
            throw 'daemon is not responding. It may be waiting on a prompt in its window; answer it there, or run nv --stop --force.'
        }
        if ($LASTEXITCODE -ne 0) { throw "remote call failed: $Function" }
        return ($out -join "`n")
    }
    finally { [Console]::OutputEncoding = $saved }
}

function Get-Status {
    return Invoke-Remote 'status' | ConvertFrom-Json
}

function Stop-Daemon([bool]$Force) {
    if (-not (Test-Daemon)) { return }
    if ($Force) {
        $me = Get-CimInstance Win32_Process -Filter "Name='nvim.exe'" |
            Where-Object { $_.CommandLine -like "*--listen*$Pipe*" }
        $me | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    }
    else {
        $status = Get-Status
        if ($status.modified.Count -gt 0) {
            throw "modified buffers, use --force to discard:`n  " + ($status.modified -join "`n  ")
        }
        Invoke-Remote 'stop' | Out-Null
    }
    if (-not (Wait-Pipe $false)) { throw 'daemon did not stop' }
}

function Open-Paths([string[]]$Paths) {
    Start-Daemon
    $cwd = $PWD.ProviderPath
    $full = @($Paths | ForEach-Object { [IO.Path]::GetFullPath($_, $cwd) })
    $request = @{ cwd = $cwd; paths = $full } | ConvertTo-Json -Compress -Depth 3
    try { $attached = Invoke-Remote 'open' $request }
    catch {
        # :qa 직후라면 파이프는 보이지만 연결은 거부된다. 종료를 기다렸다가 새로 띄운다.
        # 파이프가 그대로 남아 있으면 응답 없는 데몬이므로 원래 오류를 그대로 알린다.
        if (-not (Wait-Pipe $false 1000)) { throw }
        Start-Daemon
        $attached = Invoke-Remote 'open' $request
    }
    if ($attached -ne '1') {
        Start-Process -FilePath (Resolve-Exe 'neovide') -WorkingDirectory $HOME -ArgumentList "--server=$Pipe"
    }
}

# 스크립트 인자는 param 없이 $args로 받아 --stop 같은 인자를 그대로 전달받는다
$flags = [Collections.Generic.List[string]]::new()
$paths = [Collections.Generic.List[string]]::new()
$onlyPaths = $false
foreach ($a in $args) {
    if ($onlyPaths) { $paths.Add([string]$a) }
    elseif ($a -eq '--') { $onlyPaths = $true }
    elseif ([string]$a -like '-*') { $flags.Add([string]$a) }
    else { $paths.Add([string]$a) }
}
$force = $flags -contains '--force'
$action = @($flags | Where-Object { $_ -ne '--force' })

if ($action.Count -gt 1) { throw "only one action allowed: $($action -join ' ')" }

switch ($action[0]) {
    $null { Open-Paths $paths }
    '--help' { Show-Help }
    '-h' { Show-Help }
    '--start' { Start-Daemon }
    '--stop' { Stop-Daemon $force }
    '--restart' { Stop-Daemon $force; Start-Daemon }
    '--tui' {
        Start-Daemon
        & (Resolve-Exe 'nvim') --server $Pipe --remote-ui
    }
    '--status' {
        if (-not (Test-Daemon)) { 'not running' }
        else {
            try { Get-Status | Format-List }
            catch {
                if (-not (Wait-Pipe $false 1000)) { throw }
                'not running'
            }
        }
    }
    default { throw "unknown option: $($action[0]). See nv --help" }
}
