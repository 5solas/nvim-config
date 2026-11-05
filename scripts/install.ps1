#requires -Version 7
<#
.SYNOPSIS
  이 저장소를 Neovim/Neovide 설정으로 연결하고 nv 명령을 PATH에 추가한다. 다시 실행해도 안전하다.
.PARAMETER Autostart
  로그온할 때 데몬을 시작하도록 시작프로그램에 바로가기를 만든다.
.PARAMETER Uninstall
  이 스크립트가 만든 링크, PATH 항목, 바로가기를 제거한다. 플러그인 데이터, 도구, 폰트는 남긴다.
#>
param([switch]$Autostart, [switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Bin = Join-Path $Repo 'bin'
$Links = @{
    (Join-Path $env:LOCALAPPDATA 'nvim') = $Repo
    (Join-Path $env:APPDATA 'neovide')   = (Join-Path $Repo 'neovide')
}
$Shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'nvim-daemon.lnk'

# 이미 이 저장소를 가리키면 $true, 없으면 $false, 다른 것이 있으면 $null
function Test-OurLink([string]$Path, [string]$Target) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if ($item.LinkType -eq 'Junction' -and ([string]$item.Target).TrimEnd('\') -eq $Target.TrimEnd('\')) { return $true }
    return $null
}

if ($Uninstall) {
    foreach ($path in $Links.Keys) {
        if (Test-OurLink $path $Links[$path]) {
            # 재귀 없이 지우면 링크만 사라지고 대상 폴더는 남는다
            [IO.Directory]::Delete($path, $false)
            "removed link $path"
        }
    }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ -and $_ -ne $Bin }
    [Environment]::SetEnvironmentVariable('Path', ($userPath -join ';'), 'User')
    Remove-Item -LiteralPath $Shortcut -ErrorAction SilentlyContinue
    'uninstalled. nv --stop first if the daemon is still running. Fonts stay installed; remove Monoplex KR Nerd Font in Windows settings if unwanted.'
    return
}

# 1. 외부 도구. scoop이 없으면 빠진 목록만 알려 준다.
$scoopPackages = [ordered]@{
    nvim = 'neovim'; neovide = 'extras/neovide'; git = 'git'; rg = 'ripgrep'; fzf = 'fzf'; fd = 'fd'
    'tree-sitter' = 'tree-sitter'; gcc = 'mingw'; clangd = 'llvm'; uv = 'uv'
}
foreach ($name in $scoopPackages.Keys) {
    if (Get-Command $name -ErrorAction SilentlyContinue) { continue }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        "installing $($scoopPackages[$name])"
        if ($scoopPackages[$name] -like 'extras/*') { scoop bucket add extras 2>&1 | Out-Null }
        scoop install $scoopPackages[$name]
    }
    else { Write-Warning "$name is missing and scoop is not available" }
}
foreach ($tool in 'compiledb', 'scons') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        if (Get-Command uv -ErrorAction SilentlyContinue) { uv tool install $tool }
        else { Write-Warning "$tool is missing; :CompileDb needs it (uv tool install $tool)" }
    }
}

# 폰트 (사용자 범위 설치, 관리자 권한 불필요). 버전과 해시를 고정한다.
$MonoplexUrl = 'https://github.com/y-kim/monoplex/releases/download/monoplex-kr-nerd-font-1.2.1/MonoplexKRNerdFont_v1.2.1.zip'
$MonoplexSha256 = '4449CDB8ED9CAF083004833BFC35396119F2E09355ABFAD891551CA13C6DF2DB'
$FontStyles = 'Regular', 'Bold', 'Italic', 'BoldItalic'
$FontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$FontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -Namespace NvInstall -Name Gdi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResourceW(string file);
'@

function Test-FontInstalled([string]$Family) {
    Add-Type -AssemblyName System.Drawing
    return (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains $Family
}

function Install-Monoplex {
    $missing = @($FontStyles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $FontDir "MonoplexKRNerdFont-$_.ttf")) })
    if ($missing.Count -eq 0) { return }
    $work = Join-Path ([IO.Path]::GetTempPath()) "monoplex-$PID"
    New-Item -ItemType Directory $work | Out-Null
    try {
        $zip = Join-Path $work 'font.zip'
        Invoke-WebRequest -Uri $MonoplexUrl -OutFile $zip
        if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $MonoplexSha256) { throw 'Monoplex download hash mismatch' }
        Expand-Archive -LiteralPath $zip -DestinationPath $work
        New-Item -ItemType Directory -Force $FontDir | Out-Null
        foreach ($style in $missing) {
            $name = "MonoplexKRNerdFont-$style.ttf"
            $source = Get-ChildItem $work -Recurse -File -Filter $name | Select-Object -First 1
            $target = Join-Path $FontDir $name
            Copy-Item -LiteralPath $source.FullName -Destination $target
            New-ItemProperty -Path $FontKey -Name "Monoplex KR Nerd Font $style (TrueType)" -Value $target -PropertyType String -Force | Out-Null
            [void][NvInstall.Gdi]::AddFontResourceW($target)
        }
        'installed Monoplex KR Nerd Font'
    }
    finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Install-Monoplex
if (-not (Test-FontInstalled 'Sarasa Fixed K')) {
    Write-Warning 'Sarasa Fixed K is missing, so hanja, kana and NFD jamo fall back to a system font. scoop install nerd-fonts/SarasaGothic-K'
}

# 2. 설정 링크. 기존 폴더는 절대 덮어쓰지 않는다.
foreach ($path in $Links.Keys) {
    $state = Test-OurLink $path $Links[$path]
    if ($null -eq $state) { throw "$path already exists and is not a link to this repo. Move it away and rerun." }
    if (-not $state) {
        New-Item -ItemType Junction -Path $path -Target $Links[$path] | Out-Null
        "linked $path -> $($Links[$path])"
    }
}

# 3. PATH (사용자 범위)
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ }
if ($userPath -notcontains $Bin) {
    [Environment]::SetEnvironmentVariable('Path', (($userPath + $Bin) -join ';'), 'User')
    "added $Bin to user PATH. Open a new shell to use nv."
}
if (($env:Path -split ';') -notcontains $Bin) { $env:Path += ";$Bin" }

# 4. 플러그인과 LSP. lazy-lock.json에 고정된 버전으로 설치한다.
nvim --headless '+Lazy! restore' '+qa'
if ($LASTEXITCODE -ne 0) { throw 'plugin restore failed' }
nvim --headless '+MasonToolsInstallSync' '+qa'
if ($LASTEXITCODE -ne 0) { throw 'mason install failed' }

# 5. 로그온 시 데몬 시작 (선택)
if ($Autostart) {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($Shortcut)
    $link.TargetPath = (Get-Command pwsh).Source
    $link.Arguments = "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Bin\nv.ps1`" --start"
    $link.WindowStyle = 7
    $link.Save()
    "autostart: $Shortcut"
}

'done. Try: nv --help'
