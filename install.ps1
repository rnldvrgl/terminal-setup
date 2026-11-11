# Bootstrap for:  irm https://raw.githubusercontent.com/rnldvrgl/terminal-setup/main/install.ps1 | iex
# Downloads the latest repo ZIP to %TEMP% and launches the setup menu.
# Wrapped in a script block so nothing leaks into the caller's session. ASCII only (5.1-safe).
& {
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   # old 5.1 defaults

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir   = Join-Path $env:TEMP "terminal-setup-$stamp"
    $zip   = "$dir.zip"

    Write-Host ''
    Write-Host '  Downloading terminal-setup from GitHub...' -ForegroundColor Cyan
    try {
        Invoke-WebRequest 'https://github.com/rnldvrgl/terminal-setup/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $dir -Force
    } catch {
        Write-Host "  Download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Check your internet connection, or download the ZIP manually from https://github.com/rnldvrgl/terminal-setup' -ForegroundColor Yellow
        return
    } finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    $setup = Get-ChildItem $dir -Recurse -Filter 'setup.ps1' | Select-Object -First 1
    if (-not $setup) { Write-Host '  setup.ps1 not found in the download.' -ForegroundColor Red; return }

    # Run in a child Windows PowerShell so $PSScriptRoot and -ExecutionPolicy Bypass apply cleanly.
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $setup.FullName
}
