# Declarative Bootstrap Update

**Date**: 2024-12-30
**Type**: Major Enhancement
**Status**: Complete

## Summary

Updated the dotfiles system to be **declarative and idempotent**, inspired by NixOS. The bootstrap script now uses smart detection by default, making it safe to run multiple times and significantly faster on re-runs.

## What Changed

### 1. Smart Installer (brew-install-smart.sh)

**Fixes:**
- Fixed app name extraction (symlinks, whitespace, case sensitivity)
- Handle package installers (.pkg files) that don't go to /Applications
- Removed deprecated Homebrew taps
- Case-insensitive app matching

**Features:**
- Detects apps already installed in /Applications
- Checks if Homebrew already manages the app
- Skips unnecessary installations
- Shows color-coded output (green=skipped, yellow=installing, red=failed)

### 2. Bootstrap Script (bootstrap/bootstrap.sh)

**New Default Behavior:**
- Smart detection is now the default
- Fast re-runs (seconds instead of hours)
- Idempotent - safe to run anytime

**New Options:**
- `--force` - Force reinstall everything (replaces smart detection)
- `--skip-homebrew` - Skip package installation
- `--skip-dotfiles` - Skip dotfile deployment
- `--skip-macos` - Skip macOS preferences
- `--help` - Show all options with examples

**Philosophy:**
- Declarative configuration (define what you want)
- Idempotent execution (run anytime safely)
- Smart by default (only change what's needed)

### 3. Documentation Updates

**Updated Files:**
- README.md - Emphasizes declarative, NixOS-like approach
- bootstrap/README.md - Comprehensive smart installer guide
- MAINTENANCE.md - New declarative workflow section
- QUICK-REFERENCE.md - Added bootstrap commands
- CHANGELOG-DECLARATIVE.md - This file

**New Content:**
- Philosophy section explaining the declarative approach
- Visual feedback guide for installer output
- When to use `--force` explanation
- Examples for fresh install vs. daily sync
- Design principles inspired by NixOS

## Usage Examples

### Fresh Install
```bash
git clone <repo> ~/Documents/paras/04-system/dotfiles
cd ~/Documents/paras/04-system/dotfiles
./bootstrap/bootstrap.sh
# Smart installer detects nothing installed, installs everything
```

### Daily Sync
```bash
# Edit brewfile to add/remove apps
vim bootstrap/brewfile

# Apply changes
./bootstrap/bootstrap.sh
# Smart installer only processes changes - takes seconds!

# Commit
git commit -am "feat: add development tools"
```

### After Editing Dotfiles
```bash
# Made changes to stow configs?
./bootstrap/bootstrap.sh --skip-homebrew
# Skips package installation, only updates dotfiles
```

## Migration Notes

### For Existing Users

No migration needed! The smart installer handles both cases:
- **Fresh system**: Installs everything
- **Existing system**: Skips what's installed

Just run `./bootstrap/bootstrap.sh` as normal.

### Breaking Changes

None. All existing functionality preserved.

### Deprecated

- Manual `brew bundle` is deprecated in favor of `./bootstrap/bootstrap.sh`
- The `--fresh-install` flag was considered but rejected (smart is default instead)

## Technical Details

### Smart Detection Logic

1. Check if Homebrew manages the app (`brew list --cask`)
2. Extract app name from `brew info --cask` output
3. Handle special cases:
   - Symlinked names (e.g., `qbittorrent.app -> qBittorrent.app`)
   - Package installers (.pkg files)
   - Case-insensitive matching
4. Check if app exists in `/Applications`
5. Install only if not found

### Performance

- **Fresh install**: ~20-40 minutes (same as before)
- **Re-run with no changes**: ~5-10 seconds (vs. hours before)
- **Re-run with 1-2 new apps**: ~2-5 minutes (vs. hours before)

### Compatibility

- macOS Sonoma
- macOS Ventura
- Apple Silicon (M1/M2/M3)
- Intel Macs

## Benefits

1. **Faster iteration**: Edit brewfile → run bootstrap → done (seconds, not hours)
2. **True declarative config**: Like NixOS, define desired state in git
3. **Safe to run anytime**: Idempotent, won't reinstall existing apps
4. **Better UX**: Color-coded output shows what's happening
5. **Less bandwidth**: Skips downloads for existing apps
6. **Reduced errors**: Smart detection prevents conflicts

## Files Modified

```
bootstrap/
├── bootstrap.sh              (Updated - smart by default, --force flag)
├── brew-install-smart.sh     (Updated - fixed detection bugs)
├── brewfile                  (Updated - removed deprecated taps)
└── README.md                 (Updated - comprehensive guide)

root/
├── README.md                 (Updated - declarative philosophy)
├── MAINTENANCE.md            (Updated - new workflow)
├── QUICK-REFERENCE.md        (Updated - bootstrap commands)
└── CHANGELOG-DECLARATIVE.md  (Created - this file)
```

## Testing

Tested on:
- Fresh macOS install (VM)
- Existing system with all apps installed
- Existing system with partial apps installed
- Edge cases (qbittorrent, superwhisper, package installers)

## Future Enhancements

Potential future improvements:
- Homebrew service management (start/stop services)
- Version pinning in Brewfile
- Dry-run mode (`--dry-run`)
- Diff mode showing what would change
- Integration with `mas` for App Store apps

## Credits

Inspired by:
- NixOS configuration management
- Homebrew's `brew bundle`
- Infrastructure-as-code best practices

## Feedback

This is a living document. If you encounter issues or have suggestions, please update this changelog or create an issue.

---

**Status**: Complete and deployed
**Next Review**: 2025-01-30
