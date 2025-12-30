#!/usr/bin/env bash

################################################################################
# macos-defaults.sh - macOS System Preferences Configuration
#
# This script configures macOS system preferences for a developer-friendly
# environment. All settings are reversible via System Preferences.
#
# Usage: ./macos-defaults.sh
#
# Note: Some changes require logout/restart to take effect.
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}===> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_header "Configuring macOS System Preferences"

# Ask for administrator password upfront
sudo -v

# Keep sudo alive throughout the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

################################################################################
# General UI/UX
################################################################################

print_header "General UI/UX Settings"

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "
print_success "Disabled boot sound"

# Set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2
print_success "Set sidebar icon size to medium"

# Increase window resize speed for Cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
print_success "Increased window resize speed"

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
print_success "Expanded save panel by default"

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
print_success "Expanded print panel by default"

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
print_success "Set save to disk by default (not iCloud)"

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
print_success "Auto-quit printer app when jobs complete"

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false
print_success "Disabled 'Are you sure?' dialog for applications"

# Disable Resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false
print_success "Disabled Resume system-wide"

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
print_success "Disabled automatic termination of inactive apps"

# Reveal IP address, hostname, OS version when clicking login window clock
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
print_success "Enabled system info on login window clock click"

################################################################################
# Trackpad, mouse, keyboard
################################################################################

print_header "Trackpad, Mouse, Keyboard Settings"

# Trackpad: enable tap to click for this user and login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
print_success "Enabled tap to click"

# Trackpad: map bottom right corner to right-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
print_success "Configured trackpad right-click"

# Increase Bluetooth audio quality
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
print_success "Increased Bluetooth audio quality"

# Enable full keyboard access for all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
print_success "Enabled full keyboard access"

# Set fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
print_success "Set fast keyboard repeat rate"

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
print_success "Disabled press-and-hold for keys"

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
print_success "Disabled auto-correct"

################################################################################
# Screen
################################################################################

print_header "Screen Settings"

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
print_success "Set password required immediately after sleep"

# Save screenshots to ~/Documents/Screenshots
mkdir -p "${HOME}/Documents/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Documents/Screenshots"
print_success "Set screenshot location to ~/Documents/Screenshots"

# Save screenshots in PNG format
defaults write com.apple.screencapture type -string "png"
print_success "Set screenshot format to PNG"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true
print_success "Disabled shadow in screenshots"

# Enable subpixel font rendering on non-Apple LCDs
defaults write NSGlobalDomain AppleFontSmoothing -int 1
print_success "Enabled subpixel font rendering"

################################################################################
# Finder
################################################################################

print_header "Finder Settings"

# Finder: allow quitting via ⌘ + Q
defaults write com.apple.finder QuitMenuItem -bool true
print_success "Enabled Finder quit menu item"

# Finder: disable animations
defaults write com.apple.finder DisableAllAnimations -bool true
print_success "Disabled Finder animations"

# Set Desktop as default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"
print_success "Set Desktop as default Finder location"

# Show icons for drives on desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
print_success "Enabled desktop icons for drives"

# Finder: show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
print_success "Enabled showing hidden files"

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
print_success "Enabled showing all file extensions"

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true
print_success "Enabled Finder status bar"

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true
print_success "Enabled Finder path bar"

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
print_success "Enabled full POSIX path in Finder title"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
print_success "Set folders to sort first"

# Search current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
print_success "Set search scope to current folder"

# Disable file extension change warning
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
print_success "Disabled file extension change warning"

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0
print_success "Enabled spring loading with no delay"

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
print_success "Disabled .DS_Store on network/USB volumes"

# Auto-open new Finder window when volume is mounted
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true
print_success "Enabled auto-open for mounted volumes"

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
print_success "Set Finder default view to list"

# Disable trash warning
defaults write com.apple.finder WarnOnEmptyTrash -bool false
print_success "Disabled trash warning"

# Enable AirDrop over Ethernet
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true
print_success "Enabled AirDrop over Ethernet"

# Show ~/Library folder
chflags nohidden ~/Library
print_success "Unhid ~/Library folder"

# Show /Volumes folder
sudo chflags nohidden /Volumes
print_success "Unhid /Volumes folder"

################################################################################
# Dock
################################################################################

print_header "Dock Settings"

# Set Dock icon size
defaults write com.apple.dock tilesize -int 48
print_success "Set Dock icon size to 48"

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "scale"
print_success "Set minimize effect to scale"

# Minimize windows into application icon
defaults write com.apple.dock minimize-to-application -bool true
print_success "Enabled minimize to application"

# Show indicator lights for open applications
defaults write com.apple.dock show-process-indicators -bool true
print_success "Enabled Dock process indicators"

# Don't animate opening applications from Dock
defaults write com.apple.dock launchanim -bool false
print_success "Disabled Dock launch animations"

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1
print_success "Sped up Mission Control animations"

# Remove Dock auto-hide delay
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
print_success "Removed Dock auto-hide delay"

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true
print_success "Enabled Dock auto-hide"

# Make hidden app icons translucent
defaults write com.apple.dock showhidden -bool true
print_success "Made hidden app icons translucent"

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false
print_success "Disabled recent apps in Dock"

################################################################################
# Safari
################################################################################

print_header "Safari Settings"

# Privacy: don't send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true
print_success "Disabled sending search queries to Apple"

# Show full URL in address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
print_success "Enabled full URL in Safari address bar"

# Prevent Safari from opening safe files automatically
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
print_success "Disabled auto-open of safe files"

# Enable Safari debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
print_success "Enabled Safari debug menu"

# Enable Develop menu and Web Inspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
print_success "Enabled Safari Develop menu"

# Block pop-up windows
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
print_success "Blocked pop-up windows"

# Enable Do Not Track
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
print_success "Enabled Do Not Track"

################################################################################
# Terminal
################################################################################

print_header "Terminal Settings"

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4
print_success "Set Terminal to UTF-8 only"

# Enable Secure Keyboard Entry
defaults write com.apple.terminal SecureKeyboardEntry -bool true
print_success "Enabled secure keyboard entry"

################################################################################
# Time Machine
################################################################################

print_header "Time Machine Settings"

# Prevent Time Machine from prompting for new disks
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
print_success "Disabled Time Machine new disk prompts"

################################################################################
# Activity Monitor
################################################################################

print_header "Activity Monitor Settings"

# Show main window when launching
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
print_success "Enabled Activity Monitor main window on launch"

# Visualize CPU usage in Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5
print_success "Set Activity Monitor Dock icon to CPU usage"

# Show all processes
defaults write com.apple.ActivityMonitor ShowCategory -int 0
print_success "Set Activity Monitor to show all processes"

# Sort by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0
print_success "Set Activity Monitor to sort by CPU usage"

################################################################################
# TextEdit
################################################################################

print_header "TextEdit Settings"

# Use plain text mode for new documents
defaults write com.apple.TextEdit RichText -int 0
print_success "Set TextEdit to plain text mode"

# Open and save files as UTF-8
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
print_success "Set TextEdit encoding to UTF-8"

################################################################################
# Photos
################################################################################

print_header "Photos Settings"

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
print_success "Disabled Photos auto-open"

################################################################################
# Complete
################################################################################

print_header "Configuration Complete!"

echo "Restarting affected applications..."

# Restart affected applications
for app in "Activity Monitor" \
    "cfprefsd" \
    "Dock" \
    "Finder" \
    "Safari" \
    "SystemUIServer"; do
    killall "${app}" &> /dev/null || true
done

print_success "macOS defaults configured successfully!"
echo ""
echo "Note: Please restart your Mac for all changes to take full effect."
