<#
.SYNOPSIS
    Web-dev terminal setup for Windows 11, with a MAS-style console menu.

.USAGE
    One-liner (any PC, downloads the latest version):
        irm https://raw.githubusercontent.com/rnldvrgl/terminal-setup/main/install.ps1 | iex

    From a local copy:
        powershell -ExecutionPolicy Bypass -File .\setup.ps1          # menu
        powershell -ExecutionPolicy Bypass -File .\setup.ps1 -All     # install everything, no menu
        pwsh -File .\setup.ps1 -Export                                # save this PC's configs into .\config

    Safe to re-run: installed apps are skipped, replaced configs get timestamped .bak backups.
    Keep this file ASCII-only: Windows PowerShell 5.1 misreads non-ASCII in BOM-less scripts.
#>
param(
    [switch]$All,         # install every component without showing the menu
    [switch]$Export       # copy this PC's configs into .\config and exit
)

# 'Continue' on purpose: under 5.1, 'Stop' turns any native-exe stderr output (winget/fnm progress) into a fatal error
$ErrorActionPreference = 'Continue'
$script:failed = @()
$RepoUrl          = 'https://github.com/rnldvrgl/terminal-setup'
$ConfigDir        = Join-Path $PSScriptRoot 'config'
$TerminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$VSCodeSettings   = "$env:APPDATA\Code\User\settings.json"

# ============================================================== helpers
function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    $msg" -ForegroundColor Yellow }

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Get-PwshExe {
    $exe = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path $exe) { return $exe }
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# PowerShell 7's profile folder (follows OneDrive Documents redirection if enabled)
function Get-PwshProfileDir {
    $pwsh = Get-PwshExe
    if (-not $pwsh) { return $null }
    $p = & $pwsh -NoProfile -Command '$PROFILE.CurrentUserCurrentHost'
    return (Split-Path $p.Trim())
}

function Copy-WithBackup($source, $dest) {
    $dir = Split-Path $dest
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    if (Test-Path $dest) {
        if ((Get-FileHash $source).Hash -eq (Get-FileHash $dest).Hash) { Write-Ok "unchanged: $dest"; return }
        $bak = "$dest.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"   # timestamped so re-runs never overwrite an older backup
        Copy-Item $dest $bak -Force
        Write-Warn2 "backed up existing -> $bak"
    }
    Copy-Item $source $dest -Force
    Write-Ok "wrote: $dest"
}

# ============================================================== components
$Apps = @(
    @{ Id = 'Microsoft.PowerShell';      Name = 'PowerShell 7' }
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' }
    @{ Id = 'JanDeDobbeleer.OhMyPosh';   Name = 'oh-my-posh (prompt)' }
    @{ Id = 'Git.Git';                   Name = 'Git' }
    @{ Id = 'junegunn.fzf';              Name = 'fzf (fuzzy finder)' }
    @{ Id = 'Schniz.fnm';                Name = 'fnm (Node version manager)' }
    @{ Id = 'ajeetdsouza.zoxide';        Name = 'zoxide (smart cd)' }
    @{ Id = 'GitHub.cli';                Name = 'GitHub CLI' }
    @{ Id = 'JesseDuffield.lazygit';     Name = 'lazygit' }
    @{ Id = 'dandavison.delta';          Name = 'delta (git diffs)' }
    @{ Id = 'BurntSushi.ripgrep.MSVC';   Name = 'ripgrep' }
    @{ Id = 'sharkdp.fd';                Name = 'fd' }
    @{ Id = 'sharkdp.bat';               Name = 'bat' }
)

function Install-Apps {
    Write-Step 'Installing apps with winget'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn2 'winget not found. Update "App Installer" from the Microsoft Store, then re-run.'
        $script:failed += 'apps (no winget)'; return
    }
    foreach ($app in $Apps) {
        winget list -e --id $app.Id --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "already installed: $($app.Name)"; continue }
        Write-Host "    installing: $($app.Name) ..."
        winget install -e --id $app.Id --silent --accept-source-agreements --accept-package-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "installed: $($app.Name)" }
        else { Write-Warn2 "FAILED: $($app.Name) (exit $LASTEXITCODE)"; $script:failed += $app.Name }
    }
    Update-SessionPath
}

# Installed system-wide, not just per-user: an elevated (admin) Windows Terminal cannot see
# per-user fonts and shows "Unable to find the following fonts: JetBrainsMono NFM".
function Install-NerdFont {
    Write-Step 'Installing JetBrainsMono Nerd Font (system-wide)'
    $userFonts = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    if (Test-Path "$env:WINDIR\Fonts\JetBrainsMonoNerdFontMono-Regular.ttf") { Write-Ok 'already installed'; return }
    if (-not (Test-Path "$userFonts\JetBrainsMonoNerdFontMono-Regular.ttf")) {
        if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            Write-Warn2 'oh-my-posh not found (install Apps first), skipped'; $script:failed += 'font'; return
        }
        oh-my-posh font install JetBrainsMono   # per-user download/install
    }
    Write-Host '    copying to C:\Windows\Fonts (approve the UAC prompt) ...'
    $log = Join-Path $env:TEMP 'terminal-setup-fonts.log'
    $helper = Join-Path $PSScriptRoot 'scripts\install-fonts-system.ps1'
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$helper`" -SourceDir `"$userFonts`" -Filter `"JetBrainsMono*NerdFont*`" -LogFile `"$log`""
    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
        if (Test-Path "$env:WINDIR\Fonts\JetBrainsMonoNerdFontMono-Regular.ttf") { Write-Ok "installed (log: $log)" }
        else { Write-Warn2 "system install failed, see $log"; $script:failed += 'font (system)' }
    } catch { Write-Warn2 'UAC declined: font is per-user only, so an admin Terminal will not find it'; $script:failed += 'font (system)' }
}

function Install-PSModules {
    Write-Step 'Installing PowerShell modules (Terminal-Icons, PSFzf)'
    $pwsh = Get-PwshExe
    if (-not $pwsh) { Write-Warn2 'PowerShell 7 not found (install Apps first), skipped'; $script:failed += 'modules'; return }
    $moduleScript = @'
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
foreach ($m in 'Terminal-Icons', 'PSFzf') {
    if (Get-Module -ListAvailable -Name $m) { "    already installed: $m" }
    else { Install-Module -Name $m -Scope CurrentUser -Force; "    installed: $m" }
}
'@
    # -EncodedCommand: 5.1 strips quotes when passing a plain -Command string to another exe
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($moduleScript))
    & $pwsh -NoProfile -EncodedCommand $encoded
}

function Install-Profiles {
    Write-Step 'Applying PowerShell profiles and oh-my-posh theme'
    # lets your profile scripts run; throws harmlessly when this run itself uses -ExecutionPolicy Bypass
    try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch { }
    $profileDir = Get-PwshProfileDir
    if (-not $profileDir) { Write-Warn2 'PowerShell 7 not found (install Apps first), skipped'; $script:failed += 'profiles'; return }
    foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'profile.ps1', 'forest.omp.json') {
        Copy-WithBackup (Join-Path $ConfigDir $f) (Join-Path $profileDir $f)
    }
}

function Install-TerminalSettings {
    Write-Step 'Applying Windows Terminal settings'
    Copy-WithBackup (Join-Path $ConfigDir 'windows-terminal-settings.json') $TerminalSettings
}

function Install-VSCodeSettings {
    Write-Step 'Applying VS Code terminal settings (only adds keys you do not already have)'
    $snippetFile = Join-Path $ConfigDir 'vscode-terminal-settings.jsonc'
    if (-not (Test-Path $snippetFile)) { Write-Warn2 'no vscode-terminal-settings.jsonc in config, skipped'; return }
    $snippet = [IO.File]::ReadAllLines($snippetFile) | Where-Object { $_.Trim() }
    $utf8 = New-Object System.Text.UTF8Encoding($false)   # VS Code wants UTF-8 without BOM
    if (-not (Test-Path $VSCodeSettings)) {
        New-Item -ItemType Directory -Force (Split-Path $VSCodeSettings) | Out-Null
        [IO.File]::WriteAllText($VSCodeSettings, "{`n" + ($snippet -join "`n") + "`n}`n", $utf8)
        Write-Ok "created: $VSCodeSettings"; return
    }
    $text = [IO.File]::ReadAllText($VSCodeSettings)
    $missing = @($snippet | Where-Object {
        $key = [regex]::Match($_, '"([^"]+)"').Groups[1].Value
        $text -notmatch [regex]::Escape("`"$key`"")
    })
    if ($missing.Count -eq 0) { Write-Ok 'all terminal settings already present'; return }
    Copy-Item $VSCodeSettings "$VSCodeSettings.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    # insert right after the opening brace; every line ends with a comma, which VS Code's JSONC allows
    $insert = "`n  // added by terminal-setup`n" + (($missing | ForEach-Object { '  ' + $_.Trim().TrimEnd(',') + ',' }) -join "`n")
    $text = $text.Insert($text.IndexOf('{') + 1, $insert)
    [IO.File]::WriteAllText($VSCodeSettings, $text, $utf8)
    Write-Ok "added $($missing.Count) setting(s) to $VSCodeSettings"
}

function Install-GitConfig {
    Write-Step 'Configuring git (delta diffs, identity)'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Warn2 'git not found (install Apps first), skipped'; $script:failed += 'git config'; return }
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global merge.conflictStyle zdiff3
    git config --global init.defaultBranch main
    Write-Ok 'delta set as diff pager'
    if (-not (git config --global user.name))  { $n = Read-Host '    git user.name (Enter to skip)';  if ($n) { git config --global user.name $n } }
    if (-not (git config --global user.email)) { $e = Read-Host '    git user.email (Enter to skip)'; if ($e) { git config --global user.email $e } }
}

function Install-Node {
    Write-Step 'Installing Node LTS with fnm'
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) { Write-Warn2 'fnm not found (install Apps first), skipped'; $script:failed += 'node'; return }
    fnm install --lts
    fnm default lts-latest
    Write-Ok 'Node LTS set as default'
}

# Order matters: later components need the apps from the first one.
$Components = @(
    @{ Key = 'apps';     Name = 'Apps (PowerShell 7, Terminal, oh-my-posh, git, fzf, fnm, zoxide, gh, lazygit, delta, rg, fd, bat)'; Run = ${function:Install-Apps} }
    @{ Key = 'font';     Name = 'JetBrainsMono Nerd Font (system-wide)';               Run = ${function:Install-NerdFont} }
    @{ Key = 'modules';  Name = 'PowerShell modules (Terminal-Icons, PSFzf)';          Run = ${function:Install-PSModules} }
    @{ Key = 'profiles'; Name = 'PowerShell profiles + oh-my-posh theme';              Run = ${function:Install-Profiles} }
    @{ Key = 'terminal'; Name = 'Windows Terminal settings (theme, keys, quake)';      Run = ${function:Install-TerminalSettings} }
    @{ Key = 'vscode';   Name = 'VS Code terminal settings (merged, never replaced)';  Run = ${function:Install-VSCodeSettings} }
    @{ Key = 'git';      Name = 'Git config (delta, name/email)';                      Run = ${function:Install-GitConfig} }
    @{ Key = 'node';     Name = 'Node LTS via fnm';                                    Run = ${function:Install-Node} }
)

function Invoke-Components($selected) {
    $script:failed = @()
    foreach ($c in $selected) { & $c.Run }
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkGray
    if ($script:failed.Count) { Write-Host "  Finished with problems: $($script:failed -join ', ')" -ForegroundColor Yellow }
    else { Write-Host '  All done.' -ForegroundColor Green }
    Write-Host @'

  Next steps:
    1. Close ALL Windows Terminal windows (check Task Manager) and reopen it.
    2. Run `gh auth login` to sign in to GitHub.
    3. Reload VS Code if it was open.
'@
}

function Export-Configs {
    Write-Step "Saving this PC's configs to $ConfigDir"
    $profileDir = Get-PwshProfileDir
    New-Item -ItemType Directory -Force $ConfigDir | Out-Null
    foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'profile.ps1', 'forest.omp.json') {
        $src = if ($profileDir) { Join-Path $profileDir $f } else { $null }
        if ($src -and (Test-Path $src)) { Copy-Item $src $ConfigDir -Force; Write-Ok $f }
        else { Write-Warn2 "missing: $f" }
    }
    if (Test-Path $TerminalSettings) {
        Copy-Item $TerminalSettings (Join-Path $ConfigDir 'windows-terminal-settings.json') -Force
        Write-Ok 'windows-terminal-settings.json'
    }
    if (Test-Path $VSCodeSettings) {
        $lines = [IO.File]::ReadAllLines($VSCodeSettings) | Where-Object { $_ -match '^\s*"terminal\.integrated\.[^"]+"\s*:.*,?\s*$' }
        [IO.File]::WriteAllLines((Join-Path $ConfigDir 'vscode-terminal-settings.jsonc'), [string[]]$lines)
        Write-Ok "vscode-terminal-settings.jsonc ($(@($lines).Count) terminal.integrated.* keys)"
    }
    if (Test-Path (Join-Path $PSScriptRoot '.git')) {
        Write-Host "`n    Now push it:  cd `"$PSScriptRoot`"; git add -A; git commit -m `"Update configs`"; git push" -ForegroundColor Gray
    } else {
        Write-Warn2 'This folder is not a git clone (probably a temporary download), so these copies will not reach GitHub.'
        Write-Warn2 'Run Export from your cloned repo instead.'
    }
}

# ============================================================== menu
function Show-Header {
    Clear-Host
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host '           Terminal Setup  -  Windows web-dev terminal' -ForegroundColor Cyan
    Write-Host "           $RepoUrl" -ForegroundColor DarkGray
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Wait-Key {
    Write-Host ''
    Write-Host '  Press any key to return to the menu...' -ForegroundColor DarkGray
    [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-ComponentPicker {
    $on = @{}; foreach ($c in $Components) { $on[$c.Key] = $true }
    while ($true) {
        Show-Header
        Write-Host '  Choose components  (type a number to toggle)' -ForegroundColor White
        Write-Host ''
        for ($i = 0; $i -lt $Components.Count; $i++) {
            $c = $Components[$i]
            if ($on[$c.Key]) { $mark = '[x]'; $color = 'Green' } else { $mark = '[ ]'; $color = 'DarkGray' }
            Write-Host ("   {0}  {1} {2}" -f ($i + 1), $mark, $c.Name) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host '   [A] Select all   [N] Select none   [I] Install selected   [0] Back' -ForegroundColor Cyan
        Write-Host ''
        $choice = (Read-Host '  Choice').Trim().ToUpper()
        switch -Regex ($choice) {
            '^[1-9]$' { $idx = [int]$choice - 1; if ($idx -lt $Components.Count) { $k = $Components[$idx].Key; $on[$k] = -not $on[$k] } }
            '^A$'     { foreach ($c in $Components) { $on[$c.Key] = $true } }
            '^N$'     { foreach ($c in $Components) { $on[$c.Key] = $false } }
            '^I$'     {
                $sel = @($Components | Where-Object { $on[$_.Key] })
                if ($sel.Count -eq 0) { continue }
                Show-Header; Invoke-Components $sel; Wait-Key; return
            }
            '^0$'     { return }
        }
    }
}

function Show-Menu {
    while ($true) {
        Show-Header
        Write-Host '   [1] Install everything' -ForegroundColor White
        Write-Host '   [2] Choose components' -ForegroundColor White
        Write-Host "   [3] Save this PC's configs (export to config folder)" -ForegroundColor White
        Write-Host '   [4] Open the GitHub page' -ForegroundColor White
        Write-Host '   [0] Exit' -ForegroundColor White
        Write-Host ''
        Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host '   Safe to re-run: installed apps are skipped, replaced' -ForegroundColor DarkGray
        Write-Host '   configs are backed up with a timestamp.' -ForegroundColor DarkGray
        Write-Host ''
        switch ((Read-Host '  Choose a menu option [1,2,3,4,0]').Trim()) {
            '1' { Show-Header; Invoke-Components $Components; Wait-Key }
            '2' { Show-ComponentPicker }
            '3' { Show-Header; Export-Configs; Wait-Key }
            '4' { Start-Process $RepoUrl }
            '0' { return }
        }
    }
}

# ============================================================== entry
if ($Export)   { Export-Configs; return }
if ($All)      { Invoke-Components $Components; return }
Show-Menu
