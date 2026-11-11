# Unix aliases (ls, cat, rm, mv, cp, ps, kill) are built into PowerShell on Windows already

# Directory navigation shortcuts
function docs { Set-Location "$HOME\Documents" }
function dl { Set-Location "$HOME\Downloads" }
function desktop { Set-Location "$HOME\Desktop" }

# Custom Git aliases
function gst {
    git status
}
function gpl {
    git pull
}
function gps {
    git push
}
function gco {
    param (
        [string]$branch
    )
    git checkout $branch
}
function gcm {
    param (
        [string]$message
    )
    git commit -m "$message"
}
function gba {
    git branch -a
}