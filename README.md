# terminal-setup

One command that turns a fresh Windows 11 PC into a ready-to-use terminal for web development.

## What it's for

Setting up a terminal by hand after reinstalling Windows means installing a dozen tools, finding the right
font, fixing missing icons, and re-creating profiles and keybindings. This repo does all of that from a
single command with a simple menu, and it's safe to run again any time.

## Quick start

1. Open **PowerShell** (Start menu, type `PowerShell`).
2. Paste this and press Enter:

```powershell
irm https://raw.githubusercontent.com/rnldvrgl/terminal-setup/main/install.ps1 | iex
```

3. A menu opens:

```
   [1] Install everything
   [2] Choose components
   [3] Save this PC's configs (export to config folder)
   [4] Open the GitHub page
   [0] Exit
```

4. Pick **1** to install everything, or **2** to tick only the parts you want.
5. Click **Yes** on the Windows permission (UAC) prompts. They appear for app installs and the font.
6. When it says **All done**, close every Windows Terminal window (also check Task Manager) and open it again.

The command downloads the latest version of this repo to a temporary folder and runs `setup.ps1` from it.
You can read both scripts here before running them.

## What gets installed

| Component | Details |
|---|---|
| Apps (via winget) | PowerShell 7, Windows Terminal, oh-my-posh, Git, fzf, fnm, zoxide, GitHub CLI, lazygit, delta, ripgrep, fd, bat |
| Font | JetBrainsMono Nerd Font, installed for all users so icons work even in an admin terminal |
| PowerShell modules | Terminal-Icons (file icons in `ls`), PSFzf (fuzzy search) |
| PowerShell profile | oh-my-posh prompt (everforest theme), history suggestions, fzf, fnm, zoxide, git shortcuts |
| Windows Terminal | Dracula Webber theme, acrylic background, browser-style tab keys, split panes, quake drop-down |
| VS Code | Terminal font and PowerShell 7 as default terminal (only adds missing settings, never replaces yours) |
| Git | delta for readable diffs, asks for your name and email if not set |
| Node.js | Latest LTS via fnm; switches version automatically in folders with `.nvmrc` |

## Is it safe to re-run?

Yes.
- Apps that are already installed are skipped.
- Any config file it replaces is backed up next to the original first, as `name.<date-time>.bak`.

**Heads-up:** Windows Terminal settings and the PowerShell profiles are replaced, not merged. If you
already customized them, choose components with option **2** and leave those unticked, or copy what you
need back from the `.bak` file afterwards.

## Shortcuts after setup

Windows Terminal tabs work like a browser:

| Keys | Does |
|---|---|
| `Ctrl+T` / `Ctrl+N` | new tab / new window |
| `Ctrl+W` | close tab |
| `Ctrl+Shift+T` | reopen last closed tab |
| `Ctrl+1` ... `Ctrl+8` | go to tab 1-8 |
| `Ctrl+9` | go to last tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Alt+Shift+D` | split pane (auto direction) |
| `Alt+Shift+-` / `Alt+Shift++` | split down / right |
| `Ctrl+Alt+Shift+Arrow` | split in that direction |
| `Alt+Arrow` | move between panes |
| `Ctrl+Shift+W` | close pane |
| `Ctrl+Alt+T` | quake drop-down terminal (works from any app) |

In the shell:

| Keys / command | Does |
|---|---|
| `Ctrl+R` | fuzzy search command history |
| `Alt+T` | fuzzy search files |
| `F2` | switch suggestions between list and inline |
| `Ctrl+F` / `Ctrl+Space` | accept one word / the whole suggestion |
| `z <name>` | jump to a folder you've visited before |
| `lazygit` | git UI in the terminal |
| `gst` `gpl` `gps` `gco` `gcm` `gba` | git status / pull / push / checkout / commit -m / branch -a |
| `docs` `dl` `desktop` | go to Documents / Downloads / Desktop |

## Other ways to run it

From a downloaded or cloned copy of this repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1        # menu
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -All   # install everything, no menu
```

## Using it with your own settings

The configs in `config/` are the ones that get applied. To make it yours: fork the repo, set up your
terminal the way you like, then run menu option **3** (or `pwsh -File .\setup.ps1 -Export`) from your clone
to copy your current settings into `config/`, and push. Change the URL in `install.ps1` and `setup.ps1`
to your fork.

## After setup

- Run `gh auth login` to sign in to GitHub.
- Reload VS Code if it was open.
- No icons, or "Unable to find font"? Fully close Windows Terminal (end it in Task Manager) and reopen it.

## Requirements

Windows 11 (or Windows 10 with winget / App Installer) and an internet connection.
