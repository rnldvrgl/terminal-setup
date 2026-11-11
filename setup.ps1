<#
.SYNOPSIS
    Sets up a web-dev terminal on a fresh Windows 11 install:
    PowerShell 7, Windows Terminal, oh-my-posh, JetBrainsMono Nerd Font,
    Terminal-Icons, PSFzf, fzf, fnm + Node LTS, zoxide, gh, lazygit, delta,
    ripgrep, fd, bat, and your saved profiles / Terminal settings.

.USAGE
    Fresh machine (from Windows PowerShell, in this folder):
        powershell -ExecutionPolicy Bypass -File .\setup.ps1

    Save this machine's current configs back into .\config (after you tweak things):
        pwsh -File .\setup.ps1 -Export

    Safe to re-run: installed apps are skipped, existing configs are backed up (*.bak).
    Written to run under Windows PowerShell 5.1 (what a fresh install has).
#>
param(
    [switch]$Export,      # copy current machine configs into .\config instead of installing
    [switch]$SkipApps     # only apply configs/fonts/modules
)

# 'Continue' on purpose: under 5.1, 'Stop' turns any native-exe stderr output (winget/fnm progress) into a fatal error
$ErrorActionPreference = 'Continue'
$failed = @()
$ConfigDir = Join-Path $PSScriptRoot 'config'
$TerminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

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
    throw 'PowerShell 7 (pwsh) not found.'
}

# PowerShell 7's profile folder (follows OneDrive Documents redirection if enabled)
function Get-PwshProfileDir {
    $p = & (Get-PwshExe) -NoProfile -Command '$PROFILE.CurrentUserCurrentHost'
    return (Split-Path $p.Trim())
}

function Copy-WithBackup($source, $dest) {
    $dir = Split-Path $dest
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    if (Test-Path $dest) {
        $same = (Get-FileHash $source).Hash -eq (Get-FileHash $dest).Hash
        if ($same) { Write-Ok "unchanged: $dest"; return }
        $bak = "$dest.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"   # timestamped so re-runs never overwrite an older backup
        Copy-Item $dest $bak -Force
        Write-Warn2 "backed up existing -> $bak"
    }
    Copy-Item $source $dest -Force
    Write-Ok "wrote: $dest"
}

# ---------------------------------------------------------------- export mode
if ($Export) {
    Write-Step "Exporting current configs to $ConfigDir"
    $profileDir = Get-PwshProfileDir
    New-Item -ItemType Directory -Force $ConfigDir | Out-Null
    foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'profile.ps1', 'forest.omp.json') {
        $src = Join-Path $profileDir $f
        if (Test-Path $src) { Copy-Item $src $ConfigDir -Force; Write-Ok $f }
        else { Write-Warn2 "missing: $src" }
    }
    if (Test-Path $TerminalSettings) {
        Copy-Item $TerminalSettings (Join-Path $ConfigDir 'windows-terminal-settings.json') -Force
        Write-Ok 'windows-terminal-settings.json'
    }
    Write-Host "`nDone." -ForegroundColor Green
    return
}

# ---------------------------------------------------------------- 1. apps
$apps = @(
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

if (-not $SkipApps) {
    Write-Step 'Installing apps with winget'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Update "App Installer" from the Microsoft Store, then re-run.'
    }
    foreach ($app in $apps) {
        winget list -e --id $app.Id --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "already installed: $($app.Name)"; continue }
        Write-Host "    installing: $($app.Name) ..."
        winget install -e --id $app.Id --silent --accept-source-agreements --accept-package-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "installed: $($app.Name)" }
        else { Write-Warn2 "FAILED: $($app.Name) (exit $LASTEXITCODE)"; $failed += $app.Name }
    }
    Update-SessionPath
}

# ---------------------------------------------------------------- 2. fonts
Write-Step 'Installing JetBrainsMono Nerd Font'
Add-Type -AssemblyName System.Drawing
$families = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
if ($families -contains 'JetBrainsMono NFM') {
    Write-Ok 'already installed'
} else {
    oh-my-posh font install JetBrainsMono
    Write-Ok 'installed (use "JetBrainsMono NFM" in any app that needs icons)'
}

# ---------------------------------------------------------------- 3. PowerShell modules
Write-Step 'Installing PowerShell modules (Terminal-Icons, PSFzf)'
$moduleScript = @'
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
foreach ($m in 'Terminal-Icons', 'PSFzf') {
    if (Get-Module -ListAvailable -Name $m) { "    already installed: $m" }
    else { Install-Module -Name $m -Scope CurrentUser -Force; "    installed: $m" }
}
'@
# -EncodedCommand: 5.1 strips quotes when passing a plain -Command string to another exe
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($moduleScript))
& (Get-PwshExe) -NoProfile -EncodedCommand $encoded

# ---------------------------------------------------------------- 4. profiles + Terminal settings
Write-Step 'Applying PowerShell profiles and oh-my-posh theme'
# lets your profile scripts run; warns harmlessly when this run itself uses -ExecutionPolicy Bypass
try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch { }
$profileDir = Get-PwshProfileDir
foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'profile.ps1', 'forest.omp.json') {
    Copy-WithBackup (Join-Path $ConfigDir $f) (Join-Path $profileDir $f)
}

Write-Step 'Applying Windows Terminal settings'
Copy-WithBackup (Join-Path $ConfigDir 'windows-terminal-settings.json') $TerminalSettings

# ---------------------------------------------------------------- 5. git
Write-Step 'Configuring git'
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global merge.conflictStyle zdiff3
    git config --global init.defaultBranch main
    Write-Ok 'delta set as diff pager'
    if (-not (git config --global user.name))  { $n = Read-Host '    git user.name (Enter to skip)';  if ($n) { git config --global user.name $n } }
    if (-not (git config --global user.email)) { $e = Read-Host '    git user.email (Enter to skip)'; if ($e) { git config --global user.email $e } }
} else { Write-Warn2 'git not found, skipped' }

# ---------------------------------------------------------------- 6. Node
Write-Step 'Installing Node LTS with fnm'
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm install --lts
    fnm default lts-latest
    Write-Ok 'Node LTS set as default'
} else { Write-Warn2 'fnm not found, skipped' }

# ---------------------------------------------------------------- done
Write-Host "`nAll done." -ForegroundColor Green
if ($failed) { Write-Warn2 "These apps failed to install, re-run the script or install manually: $($failed -join ', ')" }
Write-Host @'

Next steps:
  1. Close ALL terminal windows and open Windows Terminal (fonts/PATH load on start).
  2. Run `gh auth login` to sign in to GitHub.
  3. VS Code: set "terminal.integrated.fontFamily": "JetBrainsMono NFM".
'@
