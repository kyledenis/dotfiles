# Bootstrap Scripts

Declarative macOS configuration inspired by NixOS. Define your desired system state and run `./bootstrap.sh` to converge to it.

## Philosophy

Like NixOS, this setup is:
- **Declarative**: Define what you want, not how to get there
- **Idempotent**: Run multiple times safely, only changes what's needed
- **Fast**: Smart detection skips already-installed packages
- **Complete**: Handles apps, dotfiles, macOS settings, and more

## Files

- **bootstrap.sh** - Main declarative setup script (smart by default)
- **brew-install-smart.sh** - Intelligent Homebrew installer (used by bootstrap.sh)
- **brewfile** - Comprehensive list of CLI tools, apps, and Mac App Store apps
- **macos-defaults.sh** - macOS system preferences configuration

## Quick Start

### Daily Usage (Recommended)

Run anytime to sync your system to the desired state:

```bash
cd ~/Documents/paras/04-system/dotfiles/bootstrap
./bootstrap.sh
```

This will:
- ✅ Install missing packages (skip existing ones)
- ✅ Deploy/update dotfiles with GNU Stow
- ✅ Apply macOS system preferences (with confirmation)
- ✅ Configure shell, Git, SSH, and PARAS directory structure

### Advanced Usage

```bash
# Force reinstall everything (rare, for troubleshooting)
./bootstrap.sh --force

# Skip specific sections
./bootstrap.sh --skip-macos          # Skip macOS preferences
./bootstrap.sh --skip-dotfiles       # Skip dotfile deployment
./bootstrap.sh --skip-homebrew       # Skip package installation

# See all options
./bootstrap.sh --help
```

### Manual Smart Installer

If you only want to install packages without other setup:

```bash
./brew-install-smart.sh
```

## How Smart Detection Works

The smart installer automatically detects what's already installed:

1. ✅ Checks if apps are managed by Homebrew (fastest)
2. ✅ Detects apps in /Applications with exact name matching
3. ✅ Falls back to case-insensitive matching (handles "qBittorrent.app" vs "qbittorrent.app")
4. ✅ Handles symlinked app names (e.g., "qbittorrent.app -> qBittorrent.app")
5. ✅ Skips package installers that don't go to /Applications (.pkg, installers)
6. ✅ Only installs what's missing

**Visual Feedback:**
- 🟢 Green `✓` = Managed by Homebrew
- 🟢 Green `⊙` = Found in /Applications (skipped)
- 🟡 Yellow `⊙` = Package installer (can't verify, skipped)
- 🟡 Yellow `→` = Installing now
- 🔴 Red `✗` = Failed (may require manual install/license)

## When to Use `--force`

The `--force` flag disables smart detection and reinstalls everything. Use it when:
- Smart detection is failing (shouldn't happen with current fixes)
- You want to downgrade packages
- You're debugging the smart installer
- Fresh system and want traditional `brew bundle` behavior

**99% of the time, you don't need `--force`** - the smart installer handles fresh installs perfectly.

## Notes

- All `homebrew/*` taps have been deprecated and integrated into core Homebrew
- Package installers (oversight, sf-symbols, cloudflare-warp, etc.) are skipped in app detection
- Font casks work without the deprecated `homebrew/cask-fonts` tap
- Microsoft Office apps and VirtualBox are .pkg installers, not .app bundles

## Troubleshooting

If an app fails to install:
1. Check if it requires a license (Bartender, Little Snitch, Microsoft Office, etc.)
2. Try installing manually from the vendor's website
3. Check if it requires Mac App Store sign-in
4. Some apps may require manual interaction during installation

## Examples

### Fresh macOS Install
```bash
# Clone your dotfiles
git clone <your-repo> ~/Documents/paras/04-system/dotfiles
cd ~/Documents/paras/04-system/dotfiles/bootstrap

# Run bootstrap (smart installer will detect nothing and install everything)
./bootstrap.sh
```

### Daily System Sync
```bash
# Update your Brewfile, add new apps, change settings
# Then run bootstrap to apply changes
./bootstrap.sh

# Only changed/missing items will be processed
```

### After Editing Brewfile
```bash
# Added new apps to brewfile? Just run:
./bootstrap.sh

# Only the new apps will be installed
```
