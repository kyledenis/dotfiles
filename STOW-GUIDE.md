# Stow Management Guide

Quick reference for adding and managing dotfiles with GNU Stow.

## Quick Start

### Add an Existing File

```bash
# Add any file in your home directory
dotfiles-add ~/.claude/CLAUDE.md

# Add a config file
dotfiles-add ~/.config/myapp/config.json

# Add with custom package name
dotfiles-add ~/.ssh/config ssh-config
```

### Create a New Dotfile

```bash
# Create from template and add to stow
dotfiles-add --create ~/.newrc

# Create a new config file
dotfiles-add --create ~/.config/app/settings.toml
```

That's it! The file is now:
- ✓ Moved to `stow/package/`
- ✓ Symlinked back to original location
- ✓ Tracked in git
- ✓ Ready to commit

## How It Works

### Stow Directory Structure

Stow mirrors your home directory structure:

```
~/                                  stow/package/
├── .zshrc                    →    zsh/.zshrc
├── .config/                  →    app/.config/
│   └── app/                       └── app/
│       └── config.json                └── config.json
└── .claude/                  →    claude/.claude/
    └── CLAUDE.md                      └── CLAUDE.md
```

**Key principle**: The directory structure inside `stow/package/` matches your home directory.

### Package Naming

The script auto-detects package names:

| File Location | Package Name | Reason |
|--------------|--------------|--------|
| `~/.zshrc` | `zsh` | Base dotfile → strip leading dot |
| `~/.config/starship/config.toml` | `starship` | In .config → use app name |
| `~/.claude/CLAUDE.md` | `claude` | In hidden dir → use dir name |
| `~/bin/script.sh` | `bin` | In regular dir → use dir name |

Override with: `dotfiles-add ~/.file custom-name`

## Common Scenarios

### Scenario 1: Adding Claude Config

```bash
# You created a file
echo "# Claude settings" > ~/.claude/CLAUDE.md

# Add it to dotfiles
dotfiles-add ~/.claude/CLAUDE.md

# Result:
# - File moved to: stow/claude/.claude/CLAUDE.md
# - Symlink created: ~/.claude/CLAUDE.md -> stow/claude/.claude/CLAUDE.md
# - Package: claude
```

### Scenario 2: Adding App in .config

```bash
# App created config
ls ~/.config/myapp/config.json

# Add to dotfiles
dotfiles-add ~/.config/myapp/config.json

# Result:
# - Package name: myapp (auto-detected from .config/myapp)
# - Location: stow/myapp/.config/myapp/config.json
# - Symlink: ~/.config/myapp/config.json
```

### Scenario 3: Adding Multiple Files

```bash
# Add entire directory at once
dotfiles-add ~/.config/myapp

# Or add files one by one
dotfiles-add ~/.config/myapp/config.json
dotfiles-add ~/.config/myapp/theme.css
dotfiles-add ~/.config/myapp/plugins/
```

### Scenario 4: Creating New Config

```bash
# Create a new file with template
dotfiles-add --create ~/.config/newtool/config.yaml

# Edit it
vim ~/.config/newtool/config.yaml

# It's already symlinked and tracked!
```

## Manual Process (Understanding Stow)

If you want to do it manually to understand how it works:

```bash
# 1. Create package directory
mkdir -p ~/Documents/paras/04-system/dotfiles/stow/myapp/.config/myapp

# 2. Move file to stow
mv ~/.config/myapp/config.json \
   ~/Documents/paras/04-system/dotfiles/stow/myapp/.config/myapp/

# 3. Create symlink with stow
cd ~/Documents/paras/04-system/dotfiles/stow
stow myapp

# 4. Verify
ls -la ~/.config/myapp/config.json
# Should show: ~/.config/myapp/config.json -> ../../paras/04-system/dotfiles/stow/myapp/.config/myapp/config.json

# 5. Commit
git add stow/myapp
git commit -m "Add myapp configuration"
```

## Existing Packages

Your current stow packages:

```bash
stow/
├── git/          # Git configuration
├── zsh/          # ZSH shell configuration
├── vim/          # Vim editor
├── nvim/         # Neovim editor
├── ssh/          # SSH configuration
├── onepassword/  # 1Password settings
├── atuin/        # Shell history
├── starship/     # Starship prompt
└── tmux/         # Terminal multiplexer
```

View all packages:
```bash
ls ~/Documents/paras/04-system/dotfiles/stow/
```

## Managing Packages

### Deploy a Package

```bash
cd ~/Documents/paras/04-system/dotfiles/stow
stow package-name
```

### Remove/Unstow a Package

```bash
cd ~/Documents/paras/04-system/dotfiles/stow
stow -D package-name
```

### Restow (Update) a Package

```bash
cd ~/Documents/paras/04-system/dotfiles/stow
stow -R package-name
```

### Deploy All Packages

```bash
cd ~/Documents/paras/04-system/dotfiles/stow
stow */
```

## Troubleshooting

### "Conflicts" Error

**Problem**: `stow: WARNING! stowing package would cause conflicts`

**Solution**:
```bash
# File exists but isn't a symlink yet
# Back it up first
mv ~/.file ~/.file.backup

# Then stow
stow package-name

# Compare and merge if needed
diff ~/.file.backup ~/.file
```

### "Not a symlink"

**Problem**: File exists but isn't symlinked

**Solution**:
```bash
# Unstow
stow -D package-name

# Remove the file
rm ~/.file

# Restow
stow package-name
```

### Wrong Symlink Target

**Problem**: Symlink points to wrong location

**Solution**:
```bash
# Remove symlink
rm ~/.file

# Restow
cd ~/Documents/paras/04-system/dotfiles/stow
stow -R package-name
```

## Best Practices

### 1. One Package Per Application

**Good**:
```
stow/
├── git/
├── zsh/
└── nvim/
```

**Avoid**:
```
stow/
└── configs/  # Too generic, hard to manage
    ├── .gitconfig
    ├── .zshrc
    └── .config/nvim/
```

### 2. Keep Packages Focused

Each package should contain config for one tool or closely related tools.

**Good**:
- `git/` - Just git config
- `zsh/` - ZSH and shell-related only

**Avoid**:
- `terminal-stuff/` - Too vague, hard to deploy selectively

### 3. Document Package Purpose

Add a README to complex packages:

```bash
# In stow/myapp/README.md
# MyApp Configuration

This package contains:
- Main config: ~/.config/myapp/config.json
- Themes: ~/.config/myapp/themes/
- Plugins: ~/.config/myapp/plugins/

## Setup
...
```

### 4. Test Before Committing

```bash
# Add file
dotfiles-add ~/.file

# Verify symlink
ls -la ~/.file

# Test that app still works
myapp --check-config

# Then commit
git commit -m "Add myapp config"
```

### 5. Ignore Generated Files

Some apps generate cache/state files. Don't track these!

```bash
# In stow/myapp/.gitignore
.config/myapp/cache/
.config/myapp/*.log
.config/myapp/state.json
```

## Templates

### For .md Files

```markdown
# Filename

Created: YYYY-MM-DD

## Description

[What this file is for]

## Usage

```bash
# Example
```

---

**Last Updated**: YYYY-MM-DD
```

### For .json Files

```json
{
  "created": "YYYY-MM-DD",
  "description": "Configuration file",
  "config": {
  }
}
```

### For .toml Files

```toml
# Configuration
# Created: YYYY-MM-DD

[main]
# Settings here
```

## Quick Reference Commands

```bash
# Add existing file
dotfiles-add ~/.file

# Create new file
dotfiles-add --create ~/.file

# Add with custom package
dotfiles-add ~/.file package-name

# Deploy all packages
cd ~/Documents/paras/04-system/dotfiles/stow && stow */

# Restow everything
cd ~/Documents/paras/04-system/dotfiles && ./scripts/deploy.sh --restow

# Check what's deployed
find ~ -lname '*/dotfiles/stow/*' -ls

# List all stow packages
ls ~/Documents/paras/04-system/dotfiles/stow/
```

## Advanced: Migrating Existing Configs

If you have many existing dotfiles to migrate:

```bash
# List all your current dotfiles
ls -la ~ | grep '^l'  # Existing symlinks
ls -la ~ | grep '^\.'  # Hidden files

# Add them one by one
dotfiles-add ~/.bashrc
dotfiles-add ~/.tmux.conf
dotfiles-add ~/.config/alacritty

# Or in bulk
for file in ~/.config/*/; do
    dotfiles-add "$file"
done
```

## Real Examples

### Example 1: Claude Desktop

```bash
$ dotfiles-add ~/.claude/CLAUDE.md

Configuration:
  Source file:    /Users/you/.claude/CLAUDE.md
  Relative path:  .claude/CLAUDE.md
  Package name:   claude
  Stow location:  stow/claude/.claude/CLAUDE.md

Proceed? (y/n) y

→ Creating stow package structure...
✓ Created directory structure
→ Moving file to stow...
✓ Moved file to: stow/claude/.claude/CLAUDE.md
→ Creating symlink with stow...
✓ Symlinked: ~/.claude/CLAUDE.md
✓ Staged changes for commit

Next steps:
  1. git commit -m 'Add claude configuration'
```

### Example 2: New App Config

```bash
$ dotfiles-add --create ~/.config/myapp/settings.toml

Configuration:
  Source file:    /Users/you/.config/myapp/settings.toml
  Relative path:  .config/myapp/settings.toml
  Package name:   myapp
  Stow location:  stow/myapp/.config/myapp/settings.toml

Proceed? (y/n) y

→ Creating stow package structure...
✓ Created directory structure
→ Creating new file...
✓ Created template file
→ Creating symlink with stow...
✓ Symlinked: ~/.config/myapp/settings.toml
✓ Staged changes for commit
```

---

**Last Updated**: 2024-12-28
**See Also**: MAINTENANCE.md, README.md
