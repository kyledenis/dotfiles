# Quick Reference

Cheatsheet for all available commands, aliases, and keybindings.

## Bootstrap & System Sync

```bash
./bootstrap/bootstrap.sh          # Sync system to config (smart, fast)
./bootstrap/bootstrap.sh --force  # Force reinstall everything
./bootstrap/bootstrap.sh --help   # See all options
./bootstrap/brew-install-smart.sh # Smart package installer only
```

## Shell Aliases

| Alias | Command |
|-------|---------|
| `l` | List files (eza) |
| `la` | List all including hidden |
| `ll` | Long list with details |
| `lt` | Tree view |
| `cat` | Display file (bat with syntax highlighting) |
| `..` | Go up one directory |

## Git Shortcuts

| Alias/Function | Action |
|----------------|--------|
| `gs` | Status |
| `ga` | Add |
| `gc` | Commit |
| `gp` | Push |
| `gcm <msg>` | Quick commit with message |
| `gac <msg>` | Add all + commit |
| `gacp <msg>` | Add all + commit + push |
| `gst` | Status (short format) |
| `gnb <name>` | Create new branch |
| `gdb <name>` | Delete branch (local + remote) |
| `glog` | Pretty log with graph |

## PARAS Navigation

| Command | Destination |
|---------|-------------|
| `p <name>` | Projects (`~/Documents/paras/00-projects/`) |
| `a <name>` | Areas (`~/Documents/paras/01-areas/`) |
| `r <name>` | Resources (`~/Documents/paras/02-resources/`) |
| `ar <name>` | Archive (`~/Documents/paras/03-archive/`) |
| `s <name>` | System (`~/Documents/paras/04-system/`) |
| `paras-list` | List all PARAS directories |
| `paras-archive <project>` | Archive a project with timestamp |

## Dotfiles Management

```bash
dotfiles-add <file> [pkg]   # Add file to stow management
dotfiles-update             # Pull and restow all packages
dotfiles-status             # Check git status
dotfiles-commit <msg>       # Commit changes
dotfiles-audit              # Find new apps not in Brewfile
dotfiles-add-apps           # Interactively add apps to Brewfile
dotfiles-sync               # Full workflow: audit → add → commit
```

## Development

```bash
mkcd <dir>                  # Create directory and cd into it
extract <file>              # Extract any archive type

# Python
venv-create                 # Create and activate venv
venv-activate               # Activate existing venv
pip-save <pkg>              # Install and save to requirements.txt
```

## Network

```bash
myip                        # External IP address
localip                     # Local IP address
port <num>                  # Check what's using a port
killport <num>              # Kill process on port
```

## System

```bash
cleanup [--dry-run|--all]   # Safe system cleanup
findlarge [size]            # Find large files (default 100M)
backup <file>               # Create timestamped backup
duf                         # Disk usage of current directory
```

## macOS

```bash
flushdns                    # Flush DNS cache
showhidden / hidehidden     # Toggle hidden files in Finder
lock                        # Lock screen
emptytrash                  # Empty trash
```

## Productivity

```bash
timer [duration]            # Set timer (default 5m)
countdown [seconds]         # Countdown (default 60s)
notify <msg> [title]        # macOS notification
```

## Tmux Keybindings

**Prefix: `Ctrl-a`**

| Key | Action |
|-----|--------|
| `\|` | Split horizontal |
| `-` | Split vertical |
| `h/j/k/l` | Navigate panes (vim-style) |
| `H/J/K/L` | Resize panes |
| `Alt-Arrow` | Switch panes (no prefix) |
| `c` | New window |
| `x` | Kill pane |
| `X` | Kill window |
| `S` | Sync panes toggle |
| `r` | Reload config |
| `v` | Begin selection (copy mode) |
| `y` | Copy to clipboard |
| `P` | Paste |

## Neovim Keybindings

**Leader: `Space`**

| Key | Action |
|-----|--------|
| `<leader>w` | Save |
| `<leader>q` | Quit |
| `<leader>h` | Clear search highlight |
| `Ctrl-h/j/k/l` | Navigate splits |
| `<leader>+/-` | Resize splits |
| `Alt-j/k` | Move lines |

## Stow Packages

| Package | Contents |
|---------|----------|
| `zsh` | Shell config, aliases, functions |
| `git` | Git config + work identity |
| `tmux` | Terminal multiplexer |
| `nvim` | Neovim with lazy.nvim |
| `vim` | Vim fallback |
| `ssh` | SSH config + 1Password keys |
| `starship` | Alternative prompt |
| `atuin` | Shell history sync |
| `claude` | Claude AI config |

## Key Directories

```
~/Documents/paras/04-system/dotfiles/
├── bootstrap/          # Brewfile, setup scripts
├── scripts/            # Maintenance scripts
└── stow/               # All managed dotfiles
```

## See Also

- `STOW-GUIDE.md` - How to add/manage files
- `MAINTENANCE.md` - Keeping dotfiles current
- `bootstrap/MANUAL_APPS.md` - Non-Homebrew apps
