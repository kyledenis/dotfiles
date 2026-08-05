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

### Config Detection

A read-only scan discovers new config files; adoption happens only with explicit consent in `dotfiles review`. Nothing is moved or copied in the background.

```bash
dotfiles scan         # Scan for new configs now (read-only)
dotfiles status       # Last scan time and pending candidates
dotfiles review       # Review candidates and adopt with per-package consent
```

Scans also run daily in the background, triggered on shell startup (throttled). Uses pattern files in `scripts/patterns/` to classify files:
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

### AI Skills Sync

Distributes AI agent skills from a private canonical store (`~/.skills`) to each tool's expected directory with per-tool frontmatter transformation.

```bash
skills-create <name>       # Interactive skill scaffolding
skills-sync                # Sync skills to all AI tools
skills-sync --list         # List all skills and their targets
skills-sync --dry-run      # Preview without writing
skills-sync --prune        # Remove orphaned skills from tools
```

Skills are stored in a separate private repo (`~/.skills/`) and synced to `~/.claude/skills/` and `~/.cursor/skills/`. See [skills-sync.sh](scripts/skills-sync.sh) for details.

### SSH Key Management

```bash
ssh-create <name>          # Create and register a new SSH key
ssh-list                   # List managed keys with host mappings
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
rogue ssh             # SSH key management
rogue skills          # AI skill management
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
│   └── macos-defaults.sh      # macOS system preferences
│
├── scripts/
│   ├── rogue.sh               # Quick reference command
│   ├── scan-configs.sh        # Read-only new-config detection
│   ├── deploy.sh              # Stow deployment
│   ├── stow-add.sh            # Add files to stow
│   ├── sync-apps.sh           # App audit/sync
│   ├── ssh-create.sh          # SSH key creation + 1Password
│   ├── skills-sync.sh         # AI skills distribution
│   ├── skills-create.sh       # Interactive skill scaffolding
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
│   ├── claude/                # Claude AI config (skills synced from ~/.skills)
│   ├── cursor/                # Cursor IDE rules (skills synced from ~/.skills)
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
4. Manual installs: see `bootstrap/MANUAL_APPS.md`

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

- macOS (Ventura/Sonoma/Sequoia)
- Internet connection
- Admin access
- `yq` for skills sync (`brew install yq`)
