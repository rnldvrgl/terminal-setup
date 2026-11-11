param([string]$SourceDir, [string]$Filter, [string]$LogFile)
# Copies per-user font files into C:\Windows\Fonts and registers them for all users.
$ErrorActionPreference = 'Continue'
$reg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$log = @()
foreach ($f in Get-ChildItem $SourceDir -Filter $Filter) {
    $dest = Join-Path "$env:WINDIR\Fonts" $f.Name
    try {
        if (-not (Test-Path $dest)) { Copy-Item $f.FullName $dest -ErrorAction Stop }
        # the value name is only a label; Windows reads the real family name from the file
        Set-ItemProperty -Path $reg -Name "$($f.BaseName) (TrueType)" -Value $f.Name -ErrorAction Stop
        $log += "ok: $($f.Name)"
    } catch { $log += "FAIL: $($f.Name): $($_.Exception.Message)" }
}
$log | Set-Content $LogFile
