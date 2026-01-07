# Dotfiles

Declarative macOS configuration with automatic dotfile adoption. Uses Homebrew for packages and GNU Stow for symlink management.

## Quick Start

```bash
git clone https://github.com/yourusername/dotfiles.git ~/Documents/paras/04-system/dotfiles
cd ~/Documents/paras/04-system/dotfiles
./bootstrap/bootstrap.sh
```

Run again anytime to sync—it detects what's installed and only changes what's needed.

## Features

### Auto-Adopt Daemon

A background service that automatically discovers new config files and adds them to version control.

```bash
dotfiles install      # Install the daemon (runs every 4 hours)
dotfiles status       # Check if daemon is running
dotfiles uninstall    # Remove the daemon
dotfiles run-now      # Trigger adoption manually
dotfiles dry-run      # Preview what would be adopted
dotfiles log          # View adoption log
```

Uses pattern files in `scripts/patterns/` to classify files:
- `adopt.txt` — Files to track (shell configs, editor settings, etc.)
- `ignore.txt` — Files to skip (caches, package manager state)
- `sensitive.txt` — Files to never adopt (SSH keys, API tokens, credentials)

### Dotfiles Management

```bash
dotfiles add <file> [pkg]   # Add a file to stow management
dotfiles update             # Pull latest and re-stow all packages
dotfiles st                 # Git status of dotfiles repo
dotfiles commit <msg>       # Commit changes
dotfiles audit              # Compare installed apps vs Brewfile
dotfiles add-apps           # Interactively add apps to Brewfile
dotfiles sync               # Full sync: audit → add → commit
```

### Quick Reference

```bash
rogue                 # Show all available commands
rogue dotfiles        # Dotfiles commands
rogue nav             # PARAS navigation
rogue git             # Git shortcuts
rogue python          # Python helpers
rogue network         # Network utilities
rogue system          # System utilities
```

## Shell Aliases

### PARAS Navigation

```bash
p [name]    # Projects  ~/Documents/paras/00-projects/
a [name]    # Areas     ~/Documents/paras/01-areas/
r [name]    # Resources ~/Documents/paras/02-resources/
ar [name]   # Archive   ~/Documents/paras/03-archive/
s [name]    # System    ~/Documents/paras/04-system/
```

### Git

```bash
gst              # git status (short)
gac "msg"        # git add -A && git commit
gacp "msg"       # add, commit, push
gnb <branch>     # create and checkout branch
gdb <branch>     # delete local and remote branch
glog             # pretty log with graph
```

### Python

```bash
venv-create      # Create and activate venv
venv-activate    # Activate existing venv
pip-save <pkg>   # Install and freeze to requirements.txt
```

### Network

```bash
myip             # External IP
localip          # Local IP
port <num>       # Show process on port
killport <num>   # Kill process on port
flushdns         # Flush DNS cache
```

### System

```bash
mkcd <dir>       # mkdir && cd
extract <file>   # Extract any archive
backup <file>    # Timestamped backup
cleanup          # Safe system cleanup (brew, caches, docker)
showhidden       # Show hidden files in Finder
hidehidden       # Hide hidden files
```

## Repository Structure

```
dotfiles/
├── bootstrap/
│   ├── bootstrap.sh           # Main setup script
│   ├── brew-install-smart.sh  # Smart package installer
│   ├── brewfile               # Homebrew packages
│   ├── macos-defaults.sh      # macOS system preferences
│   └── launchd/               # Auto-adopt daemon plist
│
├── scripts/
│   ├── rogue.sh               # Quick reference command
│   ├── auto-adopt.sh          # Auto-adoption logic
│   ├── setup-auto-adopt.sh    # Daemon installer
│   ├── deploy.sh              # Stow deployment
│   ├── stow-add.sh            # Add files to stow
│   ├── sync-apps.sh           # App audit/sync
│   ├── pre-commit             # Git hook
│   └── patterns/              # Auto-adopt classification
│
├── stow/                      # Managed dotfiles
│   ├── zsh/                   # Shell config, aliases, PARAS nav
│   ├── git/                   # Git config, work identity support
│   ├── nvim/                  # Neovim with lazy.nvim
│   ├── vim/                   # Vim fallback
│   ├── tmux/                  # Terminal multiplexer
│   ├── ssh/                   # SSH with 1Password agent
│   ├── starship/              # Prompt
│   ├── atuin/                 # Shell history sync
│   ├── claude/                # Claude AI config
│   ├── onepassword/           # 1Password SSH agent
│   ├── thefuck/               # Command correction
│   └── opencode/              # OpenCode config
│
├── QUICK-REFERENCE.md         # Full command reference
├── STOW-GUIDE.md              # Managing dotfiles with stow
└── MAINTENANCE.md             # Keeping things current
```

## Bootstrap Options

```bash
./bootstrap/bootstrap.sh                # Normal run (smart detection)
./bootstrap/bootstrap.sh --force        # Reinstall everything
./bootstrap/bootstrap.sh --skip-homebrew
./bootstrap/bootstrap.sh --skip-dotfiles
./bootstrap/bootstrap.sh --skip-macos
```

## Git Hooks

The pre-commit hook checks for:
- Sensitive data (passwords, API keys, private keys)
- Shell script syntax errors
- Critical files exist and aren't empty
- No `.DS_Store` or large files
- No trailing whitespace

Install with `./scripts/setup-hooks.sh`.

## Post-Install

1. Restart Mac
2. Sign into: 1Password, browsers, Slack, etc.
3. Configure git identity:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
4. Install the auto-adopt daemon: `dotfiles install`
5. Manual installs: see `bootstrap/MANUAL_APPS.md`

## Troubleshooting

**brew not found**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"      # Intel
```

**Stow conflicts**
```bash
mv ~/.zshrc ~/.zshrc.backup
cd stow && stow zsh
```

**macOS defaults not applying** — Restart or log out/in.

## Requirements

- macOS (Ventura/Sonoma)
- Internet connection
- Admin access
