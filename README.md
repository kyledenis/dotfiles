# Dotfiles

**Declarative macOS configuration** inspired by NixOS. Define your desired system state and let the scripts handle the rest.

## Philosophy

This setup is:
- **Declarative**: Define what you want (Brewfile), not how to get it
- **Idempotent**: Run `./bootstrap/bootstrap.sh` anytime, as many times as you want
- **Smart**: Automatically detects what's installed, only changes what's needed
- **Fast**: Re-runs take seconds, not hours
- **Version Controlled**: Your entire system config lives in git

## Quick Start

### New Machine Setup

```bash
# 1. Clone this repository
git clone https://github.com/yourusername/dotfiles.git ~/Documents/paras/04-system/dotfiles
cd ~/Documents/paras/04-system/dotfiles

# 2. Run the bootstrap script (smart installer automatically detects nothing installed)
./bootstrap/bootstrap.sh

# Done! Script installs everything and configures your system.
```

### Daily Usage (Existing Machine)

```bash
# Made changes to Brewfile or dotfiles? Just run:
./bootstrap/bootstrap.sh

# Smart detection installs only what's missing - takes seconds!
```

The bootstrap script will:
- ✅ Install Homebrew (if not present)
- ✅ **Smart-install** packages (skip already-installed apps)
- ✅ Deploy dotfiles via GNU Stow
- ✅ Apply macOS system preferences (with confirmation)
- ✅ Configure shell (zsh)
- ✅ Set up Git configuration
- ✅ Create PARAS directory structure

## Prerequisites

- **macOS** (tested on Ventura and Sonoma)
- **Internet connection** (for Homebrew downloads)
- **Administrator access** (sudo required for some operations)

## What's Included

### Applications (via Homebrew)

All applications are defined in [`bootstrap/brewfile`](bootstrap/brewfile):
- **Development**: Git, Node.js, Python, Docker, VS Code, etc.
- **Terminal**: Tmux, Neovim, Zsh plugins, Starship prompt
- **Productivity**: 1Password, Slack, Notion, Raycast
- **Creative**: Figma, ImageMagick, FFmpeg
- **Utilities**: Alfred, Rectangle, Hammerspoon

See [`bootstrap/MANUAL_APPS.md`](bootstrap/MANUAL_APPS.md) for apps requiring manual installation.

### Dotfiles (via GNU Stow)

Managed configuration files in [`stow/`](stow/):

| Package | Contains |
|---------|----------|
| `zsh` | Shell config, aliases, functions, PARAS navigation |
| `git` | Git configuration with work identity support |
| `tmux` | Terminal multiplexer configuration |
| `nvim` | Neovim with lazy.nvim plugin manager |
| `vim` | Vim fallback configuration |
| `ssh` | SSH config with 1Password integration |
| `starship` | Cross-shell prompt configuration |
| `atuin` | Shell history sync and search |
| `claude` | Claude AI assistant configuration |

### Scripts

Utility scripts in [`scripts/`](scripts/):
- `deploy.sh` - Deploy/update stow packages
- `stow-add.sh` - Add new files to stow management
- `sync-apps.sh` - Audit and sync installed applications
- `setup-hooks.sh` - Configure git hooks
- `pre-commit` - Git pre-commit hook

## Installation

### Recommended: Smart Setup (Default)

Run anytime to sync your system to the desired state:

```bash
./bootstrap/bootstrap.sh
```

**What it does:**
- 🔍 Detects what's already installed
- ⚡ Installs only missing packages
- 🔄 Updates dotfiles with Stow
- ⚙️ Applies macOS preferences (asks first)
- ⏱️ Completes in seconds on re-runs

### Advanced Options

```bash
# Force reinstall everything (rare, for troubleshooting)
./bootstrap/bootstrap.sh --force

# Skip specific sections
./bootstrap/bootstrap.sh --skip-homebrew    # Skip package installation
./bootstrap/bootstrap.sh --skip-dotfiles    # Skip dotfile deployment
./bootstrap/bootstrap.sh --skip-macos       # Skip macOS preferences

# See all options
./bootstrap/bootstrap.sh --help
```

### Manual Installation (Not Recommended)

If you need granular control:

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Smart package installation
./bootstrap/brew-install-smart.sh

# 3. Deploy dotfiles
cd stow && stow */

# 4. Apply macOS preferences
./bootstrap/macos-defaults.sh
```

**Note:** The smart installer is used by bootstrap.sh by default. Use `--force` only when needed.

## Post-Installation Checklist

After running the bootstrap script:

- [ ] **Restart your Mac** (required for some changes)
- [ ] **Sign in to applications**:
  - 1Password (and enable SSH agent)
  - Chrome/Arc/Brave
  - Slack, Notion, etc.
- [ ] **Configure SSH**:
  - If using 1Password SSH agent: Already configured via `stow/ssh`
  - Otherwise: Generate SSH key with `ssh-keygen -t ed25519`
- [ ] **Set up Git identity**:
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```
- [ ] **Install Mac App Store apps**:
  ```bash
  # See bootstrap/MANUAL_APPS.md for full list
  mas install 497799835  # Xcode
  mas install 409183694  # Keynote
  ```
- [ ] **Manual application installs**:
  - Adobe Lightroom (requires subscription)
  - DaVinci Resolve
  - See [`bootstrap/MANUAL_APPS.md`](bootstrap/MANUAL_APPS.md) for complete list
- [ ] **Configure macOS System Preferences**:
  - Privacy & Security settings
  - Trackpad preferences
  - Keyboard shortcuts
  - Login items
- [ ] **Set up Time Machine backups**

## Daily Usage

### Shell Aliases & Functions

See [`QUICK-REFERENCE.md`](QUICK-REFERENCE.md) for complete reference.

**Highlights:**
```bash
# PARAS navigation
p <name>      # Go to project
a <name>      # Go to area
s <name>      # Go to system

# Git shortcuts
gac "message"    # Add all + commit
gacp "message"   # Add all + commit + push

# Dotfiles management
dotfiles-add ~/.config/newapp/config.json  # Add file to stow
dotfiles-update                             # Pull and restow
dotfiles-audit                              # Find new apps
```

### Managing Dotfiles

See [`STOW-GUIDE.md`](STOW-GUIDE.md) for detailed guide.

**Quick examples:**
```bash
# Add a new config file
dotfiles-add ~/.config/myapp/settings.toml

# Create and add a new dotfile
dotfiles-add --create ~/.newrc

# Update dotfiles from git
dotfiles-update
```

### Maintaining Your Setup

See [`MAINTENANCE.md`](MAINTENANCE.md) for detailed maintenance guide.

**Weekly routine:**
```bash
# Check for new installed apps
dotfiles-audit

# Add new apps to Brewfile
dotfiles-add-apps

# Commit changes
git commit -am "Update: Add newly installed apps"
```

**Monthly routine:**
```bash
# Update all packages
brew update && brew upgrade
brew upgrade --cask
mas upgrade

# Clean up
brew cleanup -s
```

## Repository Structure

```
dotfiles/
├── README.md                   # This file - start here
├── MAINTENANCE.md              # Keeping dotfiles current
├── QUICK-REFERENCE.md          # Command cheatsheet
├── STOW-GUIDE.md              # Managing dotfiles with stow
│
├── bootstrap/                  # Setup scripts and configs
│   ├── bootstrap.sh           # Main setup script
│   ├── brewfile               # Homebrew packages
│   ├── macos-defaults.sh      # macOS system preferences
│   └── MANUAL_APPS.md         # Non-Homebrew applications
│
├── scripts/                    # Utility scripts
│   ├── deploy.sh              # Stow deployment
│   ├── stow-add.sh            # Add files to stow
│   ├── sync-apps.sh           # App synchronization
│   └── setup-hooks.sh         # Git hooks setup
│
└── stow/                       # Managed dotfiles
    ├── zsh/                   # ZSH configuration
    ├── git/                   # Git configuration
    ├── tmux/                  # Tmux configuration
    ├── nvim/                  # Neovim configuration
    ├── ssh/                   # SSH configuration
    └── ...                    # Other packages
```

## Troubleshooting

### Bootstrap Script Issues

**Problem**: "Command not found: brew"
```bash
# Add Homebrew to PATH (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Or for Intel Macs
eval "$(/usr/local/bin/brew shellenv)"
```

**Problem**: "Stow conflicts detected"
```bash
# Backup conflicting files manually
mv ~/.zshrc ~/.zshrc.backup

# Re-run stow
cd stow && stow zsh
```

### Homebrew Issues

**Problem**: "Cask not found"
```bash
# Search for the app
brew search app-name

# If renamed or removed, update brewfile
vim bootstrap/brewfile
```

### Stow Issues

**Problem**: "Symlink not created"
```bash
# Verify stow packages
ls stow/

# Re-stow a specific package
cd stow && stow -R package-name

# Force stow (use with caution)
cd stow && stow -R --adopt package-name
```

### macOS Defaults

**Problem**: "Defaults not applying"
```bash
# Some settings require restart
sudo shutdown -r now

# Or re-run the script
./bootstrap/macos-defaults.sh
```

## Customization

### Adding Your Own Apps

1. Install the app normally (any method)
2. Check if it's available via Homebrew:
   ```bash
   brew search app-name
   ```
3. If available, add to Brewfile:
   ```bash
   dotfiles-add-apps  # Interactive mode
   # Or manually:
   echo 'cask "app-name"  # Description' >> bootstrap/brewfile
   ```
4. If not available, document in `bootstrap/MANUAL_APPS.md`

### Adding Your Own Dotfiles

```bash
# Use the helper script
dotfiles-add ~/.config/myapp/config.json

# Or manually
mkdir -p stow/myapp/.config/myapp
mv ~/.config/myapp/config.json stow/myapp/.config/myapp/
cd stow && stow myapp
```

### Modifying macOS Defaults

Edit [`bootstrap/macos-defaults.sh`](bootstrap/macos-defaults.sh) and re-run:
```bash
./bootstrap/macos-defaults.sh
```

## Design Principles

These dotfiles follow several key principles inspired by NixOS and modern infrastructure-as-code:

1. **Declarative over Imperative**: Define what you want (Brewfile), not how to install it
2. **Idempotent by Default**: Run scripts anytime, as many times as needed - they're smart enough to skip what's done
3. **Smart Detection**: Automatically detects existing installations to save time and bandwidth
4. **Symlinks over Copies**: Use GNU Stow to symlink configs, not duplicate them
5. **Version Control Everything**: Track all configuration in git - your system is code
6. **Zero-to-Productive Fast**: New machine setup in under 30 minutes, re-runs in seconds
7. **Living Documentation**: Dotfiles evolve with your workflow (see MAINTENANCE.md)
8. **PARAS Integration**: Dotfiles are part of the System (04-system) in PARAS structure

## Resources

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/)
- [Homebrew Documentation](https://docs.brew.sh/)
- [macOS defaults commands](https://macos-defaults.com/)
- [PARAS Method](https://fortelabs.com/blog/para/) by Tiago Forte

## License

This is personal configuration. Feel free to fork and adapt to your needs.

## Credits

Inspired by various dotfiles repositories and the macOS community.

---

**Quick Links:**
- [Quick Reference](QUICK-REFERENCE.md) - Daily commands
- [Maintenance Guide](MAINTENANCE.md) - Keeping things current
- [Stow Guide](STOW-GUIDE.md) - Managing dotfiles
- [Manual Apps](bootstrap/MANUAL_APPS.md) - Non-Homebrew apps
