# Dotfiles Maintenance Guide

How to keep your declarative macOS configuration up-to-date and synchronized with your actual system.

## Philosophy

Your dotfiles should be a **living document** that evolves with your workflow, not a snapshot from when you first set up your system. With the new **declarative, smart-by-default** approach, maintaining your dotfiles is as simple as running `./bootstrap/bootstrap.sh` anytime you want to sync.

## 🚀 New: Declarative Workflow (Recommended)

The easiest way to keep your dotfiles current:

```bash
# 1. Edit your Brewfile when you want to add/remove apps
vim bootstrap/brewfile

# 2. Apply changes (smart installer handles the rest)
./bootstrap/bootstrap.sh

# 3. Commit
git commit -am "feat: add new apps"
```

**That's it!** The smart installer:
- ✅ Detects what's already installed
- ✅ Installs only missing packages
- ✅ Completes in seconds

## Quick Reference (Old Workflow)

If you prefer the audit-based approach:

```bash
# Check what's out of sync
sync-apps --audit

# Add newly installed apps
sync-apps --add

# Update everything
sync-apps --update

# Export current state for comparison
sync-apps --export
```

## The Maintenance Loop

### 1. Install Apps Normally (Zero Friction)

**Don't change your workflow!** Install apps however you normally would:
- Download from website
- Mac App Store
- `brew install app-name`
- Drag & drop

The system adapts to you, not the other way around.

### 2. Weekly Audit (5 minutes)

Once a week (Sunday evening, Friday afternoon, whenever):

```bash
cd ~/Documents/paras/04-system/dotfiles
./scripts/sync-apps.sh --audit
```

This shows:
- ✓ What's already in your Brewfile
- ⚠ New apps you installed that can be added
- ℹ Apps that need manual installation notes

### 3. Update Brewfile (2 minutes)

For apps available via Homebrew:

```bash
# Option 1: Interactive mode
./scripts/sync-apps.sh --add

# Option 2: Manual (if you prefer)
vim bootstrap/brewfile
# Add: cask "app-name"  # Description
```

For apps NOT in Homebrew:

```bash
# Add to manual list
vim bootstrap/MANUAL_APPS.md
```

### 4. Commit Changes (30 seconds)

```bash
git add bootstrap/brewfile bootstrap/MANUAL_APPS.md
git commit -m "Update: Add newly installed apps"
git push
```

### 5. Test Your Config (Optional but Recommended)

```bash
# Run bootstrap to verify everything works
./bootstrap/bootstrap.sh

# Should complete quickly and show "already installed" for everything
```

Done! Your dotfiles are now current and tested.

## Automated Options

### Option 1: Shell Function (Recommended)

Add to your `~/.config/zsh/functions.zsh` (already done):

```bash
# Check dotfiles sync status
dotfiles-audit() {
    cd ~/Documents/paras/04-system/dotfiles
    ./scripts/sync-apps.sh --audit
}

# Quick add new apps
dotfiles-add-apps() {
    cd ~/Documents/paras/04-system/dotfiles
    ./scripts/sync-apps.sh --add
}
```

Usage:
```bash
dotfiles-audit       # Quick check
dotfiles-add-apps    # Add new apps
```

### Option 2: Git Hook

Add a pre-push hook to remind you:

```bash
# ~/.git/hooks/pre-push
#!/bin/bash

echo "Checking for new applications..."
cd ~/Documents/paras/04-system/dotfiles
./scripts/sync-apps.sh --audit | grep -q "Not in Brewfile"

if [ $? -eq 0 ]; then
    echo ""
    echo "⚠️  You have new applications not in Brewfile!"
    echo "Run: ./scripts/sync-apps.sh --add"
    echo ""
    read -p "Continue push anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
```

### Option 3: Scheduled Reminder

Add to your calendar or task manager:
- **Weekly**: "Review dotfiles" (5 min)
- **Monthly**: "Update all packages" (10 min)

Or use `launchd` for automated checks:

```xml
<!-- ~/Library/LaunchAgents/com.user.dotfiles-audit.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.dotfiles-audit</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/kyledenis/Documents/paras/04-system/dotfiles/scripts/sync-apps.sh</string>
        <string>--audit</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>  <!-- Monday -->
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/dotfiles-audit.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.user.dotfiles-audit.plist
```

## Update Strategies

### Strategy 1: Declarative Sync (Recommended)

**When**: Anytime you make changes to Brewfile
**Effort**: Seconds
**Good for**: Everyone using the new smart bootstrap

```bash
# Edit your Brewfile to add/remove apps
vim bootstrap/brewfile

# Apply changes (smart installer only touches what changed)
./bootstrap/bootstrap.sh

# Commit the changes
git commit -am "feat: add new development tools"
```

### Strategy 2: Reactive (Minimal Effort)

**When**: Monthly
**Effort**: 10 minutes
**Good for**: Stable setups, minimal changes

```bash
# Once a month
sync-apps --audit
sync-apps --add
git commit -am "chore: monthly app audit"

# Test that everything still works
./bootstrap/bootstrap.sh
```

### Strategy 3: Proactive (Old School)

**When**: After installing any new app
**Effort**: 30 seconds per app
**Good for**: Staying current

```bash
# Right after installing new app
sync-apps --audit
# See it show up, decide if you want to add it now or later
```

### Strategy 4: Automated (Set It & Forget It)

**When**: Scheduled weekly
**Effort**: Review notification
**Good for**: Busy people

Set up the launchd plist above, check logs weekly.

## Keeping Packages Updated

### Update All Packages (Monthly)

```bash
# Full update
sync-apps --update

# Or manually:
brew update           # Update Homebrew
brew upgrade          # Upgrade formulas
brew upgrade --cask   # Upgrade casks
mas upgrade           # Upgrade App Store apps
brew cleanup -s       # Clean old versions
```

### Pin Packages (Optional)

If an app breaks after update:

```bash
# Pin a specific version
brew pin package-name

# Unpin later
brew unpin package-name
```

### Check What Would Update

```bash
# See what's outdated
brew outdated
brew outdated --cask
mas outdated
```

## Handling Different Scenarios

### Scenario: Trying a New App

**Don't add to Brewfile immediately!**

1. Install and try the app normally
2. After 1-2 weeks, if you're still using it:
   ```bash
   sync-apps --add
   ```
3. If you uninstall it, no cleanup needed

### Scenario: App Updated Its Name

Example: "App 2.0" vs "App"

1. Remove old entry from Brewfile
2. Add new entry
3. Update MANUAL_APPS.md if needed

```bash
# In brewfile
- cask "old-app-name"
+ cask "new-app-name"
```

### Scenario: App Now Available via Homebrew

1. Remove from MANUAL_APPS.md
2. Add to brewfile
3. Test that `brew install --cask app-name` works

### Scenario: You Uninstalled Apps

```bash
# Export current state
sync-apps --export

# Compare and update
diff bootstrap/brewfile bootstrap/brewfile.current

# Remove lines for uninstalled apps
vim bootstrap/brewfile
```

## Dotfile Hygiene

### Keep It Clean

**Review quarterly** (15 minutes):

```bash
# Check what's in Brewfile but not installed
sync-apps --audit

# Remove apps you no longer use
vim bootstrap/brewfile

# Commit cleanup
git commit -am "Cleanup: Remove unused applications"
```

### Document Why

For unusual apps, add comments:

```bash
cask "obscure-app"  # Required for work project X
```

This helps future you remember why it's there.

### Categorize Properly

Keep related apps together:

```bash
# Good
cask "docker"
cask "docker-compose"
cask "kubernetes-cli"

# Bad (scattered)
cask "docker"
cask "firefox"
cask "docker-compose"
```

## Troubleshooting

### "Cask not found" Error

App might have been removed or renamed:

```bash
# Search for it
brew search app-name

# Check if it exists
brew info --cask app-name

# If gone, move to MANUAL_APPS.md
```

### Brewfile Conflicts

If `brew bundle` fails:

```bash
# See what's wrong
brew bundle check --file=bootstrap/brewfile

# Skip problematic apps
brew bundle --file=bootstrap/brewfile --no-upgrade
```

### Apps in Multiple Places

Some apps might be in both Brewfile and App Store:

```bash
# Prefer Homebrew (easier to update)
# Remove from Mac App Store section
# Keep in cask section
```

## Best Practices

1. **Audit weekly** - Make it a habit
2. **Commit often** - Small changes are easier to review
3. **Update monthly** - Balance stability and currency
4. **Review quarterly** - Remove unused apps
5. **Document unusual** - Future you will thank you
6. **Test on VM** - Before major updates
7. **Keep it simple** - Don't over-engineer

## Integration with PARAS

### Project-Specific Apps

When starting a new project that needs specific tools:

```bash
# Document in project README
echo "Required tools: docker, postgres, redis" > project/README.md

# Add to Brewfile if generally useful
# OR document in project setup only if one-off
```

### Archive Apps with Projects

When archiving a project:

1. Check if any apps are project-specific
2. If no longer needed, remove from Brewfile
3. Document in project archive what was needed

## Quick Win: Aliases

Add these to your shell config:

```bash
# Already in your functions.zsh
alias da='dotfiles-audit'          # Quick audit
alias daa='dotfiles-add-apps'      # Add apps
alias du='sync-apps --update'      # Update all
```

## Summary

**The key**: Make maintenance so easy you actually do it.

- **Zero friction** when installing apps
- **Quick audit** shows what's new (30 seconds)
- **Easy updates** with one command (2 minutes)
- **Regular rhythm** prevents drift (weekly)

Your dotfiles stay current without becoming a chore.

---

**Next Review**: Set a calendar reminder for next Sunday
**Last Updated**: 2024-12-28
