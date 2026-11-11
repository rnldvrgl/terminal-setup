# Prompt: oh-my-posh with a local theme file (faster than fetching from GitHub each start)
oh-my-posh init pwsh --config "$PSScriptRoot\forest.omp.json" | Invoke-Expression

Import-Module -Name Terminal-Icons # Icons when listing directories
Import-Module -Name PSReadLine # typeahead predictions and whatnot
Import-Module -Name PSFzf # Ctrl+T file search, Ctrl+R history search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Advanced completion features (arrow up and down after having started typing)
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Autocomplete suggestions
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete # options: [Complete|MenuComplete]

# Autocomplete predictions [HistoryAndPlugin, History, Plugin] requires PS 7.1+
Set-PSReadLineOption -PredictionSource HistoryAndPlugin # accept prediction using right arrow
Set-PSReadLineOption -PredictionViewStyle ListView # dropdown list; press F2 to toggle inline view
Set-PSReadLineOption -Colors @{ InlinePrediction = '#888888' }

# accepting suggestions
Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function ForwardWord # Accept one word
Set-PSReadLineKeyHandler -Chord "Ctrl+Spacebar" -Function ForwardChar # Accept full suggestion

# fnm: Node version manager, auto-switches on cd into a folder with .nvmrc / .node-version
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
    # fnm only wraps `cd`; also switch on any location change (z, Set-Location, Push-Location)
    $ExecutionContext.InvokeCommand.LocationChangedAction = { Set-FnmOnLoad }
}

# zoxide: `z <partial-name>` jumps to frequently used folders (keep this last)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
