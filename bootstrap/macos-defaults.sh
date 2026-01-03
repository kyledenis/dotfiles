#!/usr/bin/env bash

################################################################################
# macos-defaults.sh - macOS System Preferences Configuration
#
# This script configures macOS system preferences declaratively.
# Similar to NixOS configuration - run this to reproduce your setup.
#
# Legend:
#   [CUSTOM]  = Your current setting DIFFERS from macOS default - already/pending apply
#   [DEFAULT] = Your current setting matches macOS default - no action needed
#
# Usage: ./macos-defaults.sh
#
# To find a setting's current value: defaults read <domain> <key>
# To reset to default: defaults delete <domain> <key>
#
# Note: Some changes require logout/restart to take effect.
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}===> $1${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_header "Configuring macOS System Preferences"

# Ask for administrator password upfront
sudo -v

# Keep sudo alive throughout the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

################################################################################
# SIDEBAR ICON SIZE                                                   [DEFAULT]
################################################################################
#
# Controls the size of icons in Finder sidebars and other system sidebars
#
# Options:
#   1 = Small
#   2 = Medium (macOS default)
#   3 = Large
#
# Your current value: not set (using macOS default: 2)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1  # Small
# defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2  # Medium
# defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 3  # Large
# print_success "Set sidebar icon size"

################################################################################
# SAVE PANEL EXPANSION                                                [DEFAULT]
################################################################################
#
# Controls whether the save dialog starts expanded (showing full directory tree)
# or collapsed (simplified view)
#
# Options:
#   true  = Always start expanded (shows full directory browser)
#   false = Start collapsed (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
# defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
# print_success "Expanded save panel by default"

################################################################################
# PRINT PANEL EXPANSION                                               [DEFAULT]
################################################################################
#
# Controls whether the print dialog starts expanded (showing all options)
#
# Options:
#   true  = Always start expanded
#   false = Start collapsed (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
# defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
# print_success "Expanded print panel by default"

################################################################################
# DEFAULT SAVE LOCATION                                               [DEFAULT]
################################################################################
#
# Where new documents are saved by default
#
# Options:
#   true  = Save to iCloud by default (macOS default)
#   false = Save to local disk by default
#
# Your current value: not set (using macOS default: iCloud)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
# print_success "Set default save location to local disk"

################################################################################
# AUTO-QUIT PRINTER APP                                               [DEFAULT]
################################################################################
#
# Automatically close the printer app when all print jobs complete
#
# Options:
#   true  = Auto-quit when done
#   false = Keep printer app open (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
# print_success "Enabled auto-quit printer app"

################################################################################
# APPLICATION LAUNCH CONFIRMATION                                     [DEFAULT]
################################################################################
#
# The "Are you sure you want to open this application?" Gatekeeper dialog
#
# Options:
#   true  = Show confirmation dialog (macOS default, more secure)
#   false = Don't show confirmation (convenient but less secure)
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# WARNING: Disabling this reduces security. Only disable if you understand risks.
# defaults write com.apple.LaunchServices LSQuarantine -bool false
# print_success "Disabled app launch confirmation dialog"

################################################################################
# LOGIN WINDOW INFO                                                   [DEFAULT]
################################################################################
#
# Show system info (IP, hostname, OS version) when clicking the clock on login
# Useful for IT/admin purposes
#
# Options:
#   HostName = Show system info on clock click
#   (delete key) = Don't show (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
# print_success "Enabled system info on login window"

################################################################################
# TRACKPAD: TAP TO CLICK                                               [CUSTOM]
################################################################################
#
# Enable tapping the trackpad to click (instead of pressing down)
#
# Options:
#   true / 1 = Tap to click enabled
#   false / 0 = Must physically press trackpad (macOS default)

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
print_success "Enabled tap to click"

################################################################################
# TRACKPAD: RIGHT-CLICK                                                [CUSTOM]
################################################################################
#
# Enable secondary click (right-click) on trackpad
#
# There are TWO methods for right-click - you can enable either or both:
#
# 1. Two-finger click (TrackpadRightClick):
#      true  = Two-finger tap triggers right-click
#      false = Disabled (macOS default)
#
# 2. Corner click (TrackpadCornerSecondaryClick):
#      0 = Disabled (macOS default)
#      1 = Bottom-left corner triggers right-click
#      2 = Bottom-right corner triggers right-click
#
# enableSecondaryClick is the master toggle:
#      true  = Secondary click enabled
#      false = No right-click at all (macOS default)

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
# Also enable corner click:
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
print_success "Enabled trackpad two-finger right-click"

################################################################################
# BLUETOOTH AUDIO QUALITY                                             [DEFAULT]
################################################################################
#
# Minimum bitpool for Bluetooth audio (higher = better quality, more bandwidth)
#
# Options:
#   2-64 range, higher is better quality
#   40 = Good balance of quality and stability
#   64 = Maximum quality (may cause stuttering)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
# print_success "Increased Bluetooth audio quality"

################################################################################
# FULL KEYBOARD ACCESS                                                 [CUSTOM]
################################################################################
#
# Use Tab to navigate between all UI controls (not just text fields)
#
# Options:
#   1 = Text boxes and lists only (macOS default)
#   2 = Text boxes, lists, and buttons
#   3 = All controls (full keyboard navigation)

defaults write NSGlobalDomain AppleKeyboardUIMode -int 2
print_success "Enabled keyboard access for buttons"

################################################################################
# KEYBOARD REPEAT RATE                                                [DEFAULT]
################################################################################
#
# How fast keys repeat when held down
#
# KeyRepeat options (lower = faster):
#   1 = Fastest (15ms)
#   2 = Fast (30ms)
#   5 = Normal (83ms, macOS default)
#   6 = Slow (100ms)
#
# InitialKeyRepeat options (lower = faster, before repeat starts):
#   10 = Fastest (167ms)
#   15 = Fast (250ms)
#   25 = Normal (417ms, macOS default)
#   35 = Slow (583ms)
#
# Your current value: KeyRepeat=5, InitialKeyRepeat=25
# Status: Using defaults - no action needed
#
# Uncomment to set faster repeat:
# defaults write NSGlobalDomain KeyRepeat -int 2
# defaults write NSGlobalDomain InitialKeyRepeat -int 15
# print_success "Set fast keyboard repeat"

################################################################################
# PRESS AND HOLD FOR SPECIAL CHARACTERS                               [DEFAULT]
################################################################################
#
# When holding a key, show accent character popup vs. key repeat
#
# Options:
#   true  = Show accent popup (e.g., hold 'e' shows e/e/e) - macOS default
#   false = Enable key repeat instead (useful for vim/coding)
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# print_success "Disabled press-and-hold for key repeat"

################################################################################
# AUTO-CORRECT                                                        [DEFAULT]
################################################################################
#
# Automatic spelling correction while typing
#
# Options:
#   true  = Enable auto-correct (macOS default)
#   false = Disable auto-correct
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
# print_success "Disabled auto-correct"

################################################################################
# SCREEN LOCK PASSWORD                                                [DEFAULT]
################################################################################
#
# Require password after sleep or screen saver
#
# askForPassword options:
#   1 = Require password (macOS default on most setups)
#   0 = Don't require password
#
# askForPasswordDelay options (seconds):
#   0 = Immediately
#   5, 60, 300, etc. = Delay in seconds
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.screensaver askForPassword -int 1
# defaults write com.apple.screensaver askForPasswordDelay -int 0
# print_success "Password required immediately after sleep"

################################################################################
# SCREENSHOT LOCATION                                                 [DEFAULT]
################################################################################
#
# Where screenshots are saved
#
# Options: Any valid directory path
#   ~/Desktop (macOS default)
#   ~/Documents/Screenshots
#   ~/Pictures/Screenshots
#
# Your current value: not set (using macOS default: ~/Desktop)
# Status: Using default - no action needed
#
# mkdir -p "${HOME}/Documents/Screenshots"
# defaults write com.apple.screencapture location -string "${HOME}/Documents/Screenshots"
# print_success "Set screenshot location"

################################################################################
# SCREENSHOT FORMAT                                                   [DEFAULT]
################################################################################
#
# File format for screenshots
#
# Options:
#   png  = Lossless, larger files (macOS default)
#   jpg  = Compressed, smaller files
#   gif  = For simple graphics
#   pdf  = Vector format
#   tiff = High quality, large files
#
# Your current value: not set (using macOS default: png)
# Status: Using default - no action needed
#
# defaults write com.apple.screencapture type -string "png"
# print_success "Set screenshot format"

################################################################################
# SCREENSHOT SHADOW                                                   [DEFAULT]
################################################################################
#
# Include window shadow in screenshots
#
# Options:
#   false = Include shadow (macOS default, confusingly named)
#   true  = No shadow (cleaner look)
#
# Your current value: not set (using macOS default: shadow included)
# Status: Using default - no action needed
#
# defaults write com.apple.screencapture disable-shadow -bool true
# print_success "Disabled screenshot shadow"

################################################################################
# FINDER: QUIT MENU ITEM                                              [DEFAULT]
################################################################################
#
# Allow quitting Finder via Cmd+Q (it normally can't be quit)
#
# Options:
#   true  = Allow quitting Finder
#   false = Cannot quit Finder (macOS default)
#
# Note: Quitting Finder hides desktop icons
#
# Your current value: not set (using macOS default: false)
# Status: Using default - no action needed
#
# defaults write com.apple.finder QuitMenuItem -bool true
# print_success "Enabled Finder quit menu"

################################################################################
# FINDER: ANIMATIONS                                                  [DEFAULT]
################################################################################
#
# Finder window animations (opening, closing, info panels)
#
# Options:
#   true  = Disable animations (snappier)
#   false = Enable animations (macOS default)
#
# Your current value: not set (using macOS default: animations enabled)
# Status: Using default - no action needed
#
# defaults write com.apple.finder DisableAllAnimations -bool true
# print_success "Disabled Finder animations"

################################################################################
# FINDER: NEW WINDOW DEFAULT LOCATION                                  [CUSTOM]
################################################################################
#
# What folder opens when you create a new Finder window
#
# NewWindowTarget options:
#   PfCm = Computer
#   PfVo = Volume (Macintosh HD)
#   PfHm = Home folder
#   PfDe = Desktop (macOS default)
#   PfDo = Documents
#   PfAF = All My Files
#   PfLo = Other (specify with NewWindowTargetPath)

defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
print_success "Set new Finder window to Home folder"

################################################################################
# FINDER: DESKTOP DRIVE ICONS                                         [DEFAULT]
################################################################################
#
# Show icons on desktop for mounted drives
#
# Options (each is independent):
#   true  = Show icons on desktop (macOS default for external/removable)
#   false = Hide icons from desktop
#
# Your current value: ShowExternalHardDrivesOnDesktop = 1 (matches default)
# Status: Using defaults - no action needed
#
# defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
# defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
# defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
# defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
# print_success "Configured desktop drive icons"

################################################################################
# FINDER: SHOW HIDDEN FILES                                           [DEFAULT]
################################################################################
#
# Display files that start with . (hidden files)
#
# Options:
#   true  = Show hidden files
#   false = Hide hidden files (macOS default)
#
# Your current value: 0 (false - matches default)
# Status: Using default - no action needed
#
# Tip: Toggle with Cmd+Shift+. in Finder
#
# defaults write com.apple.finder AppleShowAllFiles -bool true
# print_success "Enabled showing hidden files"

################################################################################
# FINDER: SHOW FILE EXTENSIONS                                        [DEFAULT]
################################################################################
#
# Always show filename extensions (.txt, .pdf, etc.)
#
# Options:
#   true  = Always show extensions
#   false = Show only for some files (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# print_success "Enabled showing file extensions"

################################################################################
# FINDER: STATUS BAR                                                   [CUSTOM]
################################################################################
#
# Show status bar at bottom of Finder windows (shows item count, disk space)
#
# Options:
#   true  = Show status bar
#   false = Hide status bar (macOS default)

defaults write com.apple.finder ShowStatusBar -bool true
print_success "Enabled Finder status bar"

################################################################################
# FINDER: PATH BAR                                                     [CUSTOM]
################################################################################
#
# Show path bar at bottom of Finder windows (shows folder hierarchy)
#
# Options:
#   true  = Show path bar
#   false = Hide path bar (macOS default)

defaults write com.apple.finder ShowPathbar -bool true
print_success "Enabled Finder path bar"

################################################################################
# FINDER: POSIX PATH IN TITLE                                         [DEFAULT]
################################################################################
#
# Show full POSIX path in Finder window title bar (e.g., /Users/you/Documents)
#
# Options:
#   true  = Show full path (useful for developers)
#   false = Show folder name only (macOS default)
#
# Your current value: not set (using macOS default: false)
# Status: Using default - no action needed
#
# defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
# print_success "Enabled POSIX path in Finder title"

################################################################################
# FINDER: FOLDERS ON TOP                                              [DEFAULT]
################################################################################
#
# Keep folders at the top when sorting by name
#
# Options:
#   true  = Folders always sorted first
#   false = Folders mixed with files alphabetically (macOS default)
#
# Your current value: not set (using macOS default: false)
# Status: Using default - no action needed
#
# defaults write com.apple.finder _FXSortFoldersFirst -bool true
# print_success "Enabled folders sorted first"

################################################################################
# FINDER: DEFAULT SEARCH SCOPE                                         [CUSTOM]
################################################################################
#
# When searching in Finder, where does it search by default?
#
# Options:
#   SCcf = Current folder
#   SCsp = Previous search scope
#   SCev = Entire Mac (macOS default)

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
print_success "Set Finder search to current folder"

################################################################################
# FINDER: EXTENSION CHANGE WARNING                                    [DEFAULT]
################################################################################
#
# Warn when changing a file extension
#
# Options:
#   true  = Show warning (macOS default)
#   false = Don't warn
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# print_success "Disabled extension change warning"

################################################################################
# FINDER: SPRING LOADING                                              [DEFAULT]
################################################################################
#
# When dragging files, hover over folder to open it (spring loading)
#
# com.apple.springing.enabled: true/false (default: true)
# com.apple.springing.delay: seconds (0 = instant, 0.5 = default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write NSGlobalDomain com.apple.springing.enabled -bool true
# defaults write NSGlobalDomain com.apple.springing.delay -float 0.5
# print_success "Configured spring loading"

################################################################################
# FINDER: .DS_STORE ON NETWORK/USB                                    [DEFAULT]
################################################################################
#
# Create .DS_Store files on network and USB volumes
# These store folder view settings but can be annoying on shared drives
#
# Options:
#   true  = Don't create .DS_Store on network/USB
#   false = Create .DS_Store everywhere (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
# defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
# print_success "Disabled .DS_Store on network/USB"

################################################################################
# FINDER: DEFAULT VIEW STYLE                                          [DEFAULT]
################################################################################
#
# Default view style for new Finder windows
#
# Options:
#   icnv = Icon view (macOS default, your current setting)
#   Nlsv = List view
#   clmv = Column view
#   glyv = Gallery view
#
# Your current value: icnv (icon view)
# Status: Matches default - no action needed
#
# defaults write com.apple.finder FXPreferredViewStyle -string "icnv"
# print_success "Set Finder default view"

################################################################################
# FINDER: EMPTY TRASH WARNING                                         [DEFAULT]
################################################################################
#
# Warn before emptying the Trash
#
# Options:
#   true  = Show warning (macOS default)
#   false = Empty without warning
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write com.apple.finder WarnOnEmptyTrash -bool false
# print_success "Disabled trash warning"

################################################################################
# AIRDROP OVER ETHERNET                                               [DEFAULT]
################################################################################
#
# Enable AirDrop on wired networks
#
# Options:
#   true  = Enable AirDrop over Ethernet
#   false = Wi-Fi only (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true
# print_success "Enabled AirDrop over Ethernet"

################################################################################
# SHOW ~/LIBRARY FOLDER                                               [DEFAULT]
################################################################################
#
# The ~/Library folder is hidden by default. This makes it visible in Finder.
#
# Options:
#   nohidden = Show the folder
#   hidden   = Hide the folder (macOS default)
#
# Your current value: (check with: ls -lO ~/Library | grep hidden)
# Status: Using default - no action needed
#
# chflags nohidden ~/Library
# print_success "Unhid ~/Library folder"

################################################################################
# DOCK: ICON SIZE                                                     [DEFAULT]
################################################################################
#
# Size of Dock icons in pixels
#
# Options: 16-128 pixels
#   36 = Small
#   48 = Medium (typical default)
#   64 = Large
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.dock tilesize -int 48
# print_success "Set Dock icon size"

################################################################################
# DOCK: MINIMIZE EFFECT                                               [DEFAULT]
################################################################################
#
# Animation when minimizing windows
#
# Options:
#   genie = Genie effect (macOS default)
#   scale = Scale effect (simpler, faster)
#   suck  = Suck effect (hidden option)
#
# Your current value: not set (using macOS default: genie)
# Status: Using default - no action needed
#
# defaults write com.apple.dock mineffect -string "scale"
# print_success "Set minimize effect"

################################################################################
# DOCK: MINIMIZE TO APPLICATION ICON                                   [CUSTOM]
################################################################################
#
# Where minimized windows go
#
# Options:
#   true  = Minimize into app icon
#   false = Minimize to right side of Dock (macOS default)

defaults write com.apple.dock minimize-to-application -bool true
print_success "Enabled minimize to application"

################################################################################
# DOCK: PROCESS INDICATORS                                            [DEFAULT]
################################################################################
#
# Show dots under running application icons
#
# Options:
#   true  = Show indicators (macOS default)
#   false = Hide indicators
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write com.apple.dock show-process-indicators -bool true
# print_success "Enabled Dock indicators"

################################################################################
# DOCK: LAUNCH ANIMATION                                              [DEFAULT]
################################################################################
#
# Animate icons when launching applications (bouncing)
#
# Options:
#   true  = Bouncing animation (macOS default)
#   false = No animation
#
# Your current value: not set (using macOS default: true)
# Status: Using default - no action needed
#
# defaults write com.apple.dock launchanim -bool false
# print_success "Disabled launch animation"

################################################################################
# DOCK: MISSION CONTROL ANIMATION SPEED                               [DEFAULT]
################################################################################
#
# Speed of Mission Control animations (seconds)
#
# Options:
#   0.1  = Very fast
#   0.2  = Fast
#   ~0.5 = Normal (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.dock expose-animation-duration -float 0.1
# print_success "Sped up Mission Control"

################################################################################
# DOCK: AUTO-HIDE                                                      [CUSTOM]
################################################################################
#
# Automatically hide and show the Dock
#
# autohide: true/false (macOS default: false)
# autohide-delay: seconds before Dock appears (0 = instant)
# autohide-time-modifier: animation duration (0 = instant, 0.5 = default)

defaults write com.apple.dock autohide -bool true
# Optional: instant show (uncomment if desired)
# defaults write com.apple.dock autohide-delay -float 0
# defaults write com.apple.dock autohide-time-modifier -float 0.3
print_success "Enabled Dock auto-hide"

################################################################################
# DOCK: HIDDEN APP TRANSLUCENCY                                       [DEFAULT]
################################################################################
#
# Make icons of hidden applications translucent
#
# Options:
#   true  = Hidden apps appear faded
#   false = All apps appear same (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.dock showhidden -bool true
# print_success "Enabled hidden app translucency"

################################################################################
# DOCK: RECENT APPLICATIONS                                            [CUSTOM]
################################################################################
#
# Show recent applications section in Dock
#
# Options:
#   true  = Show recent apps (macOS default)
#   false = Hide recent apps

defaults write com.apple.dock show-recents -bool false
print_success "Disabled recent apps in Dock"

################################################################################
# SAFARI: SEARCH SUGGESTIONS                                          [DEFAULT]
################################################################################
#
# Send search queries to Apple for suggestions
#
# Options:
#   true  = Send queries (macOS default)
#   false = Don't send queries (more private)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.Safari UniversalSearchEnabled -bool false
# defaults write com.apple.Safari SuppressSearchSuggestions -bool true
# print_success "Disabled Safari search suggestions"

################################################################################
# SAFARI: FULL URL                                                    [DEFAULT]
################################################################################
#
# Show complete URL in address bar
#
# Options:
#   true  = Show full URL (e.g., https://example.com/page)
#   false = Show simplified URL (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
# print_success "Enabled full URL in Safari"

################################################################################
# SAFARI: SAFE DOWNLOADS AUTO-OPEN                                    [DEFAULT]
################################################################################
#
# Automatically open "safe" files after downloading
#
# Options:
#   true  = Auto-open safe files (macOS default)
#   false = Don't auto-open
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
# print_success "Disabled auto-open downloads"

################################################################################
# SAFARI: DEVELOPER MENU                                              [DEFAULT]
################################################################################
#
# Enable the Develop menu and Web Inspector
#
# Options:
#   true  = Show Develop menu
#   false = Hide Develop menu (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.Safari IncludeDevelopMenu -bool true
# defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
# defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
# print_success "Enabled Safari Develop menu"

################################################################################
# SAFARI: DO NOT TRACK                                                [CUSTOM]
################################################################################
#
# Send "Do Not Track" header with requests
#
# Options:
#   true  = Send DNT header
#   false = Don't send (macOS default)
#
# Note: Many websites ignore this header
# Note: Safari is sandboxed on modern macOS - preferences must be set manually
#       through Safari > Settings (cannot use defaults write)

# defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
# print_success "Enabled Do Not Track"
print_info "Safari preferences must be configured manually (sandboxed app)"

################################################################################
# TERMINAL: ENCODING                                                  [DEFAULT]
################################################################################
#
# Text encoding for Terminal.app
#
# Options (array of encoding values):
#   4 = UTF-8 only
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.terminal StringEncodings -array 4
# print_success "Set Terminal to UTF-8"

################################################################################
# TERMINAL: SECURE KEYBOARD ENTRY                                     [DEFAULT]
################################################################################
#
# Prevent other applications from reading keyboard input in Terminal
#
# Options:
#   true  = Enable secure input
#   false = Disable (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.terminal SecureKeyboardEntry -bool true
# print_success "Enabled secure keyboard entry"

################################################################################
# TIME MACHINE: NEW DISK PROMPTS                                      [DEFAULT]
################################################################################
#
# Prompt to use new disks as Time Machine backup
#
# Options:
#   true  = Don't prompt for new disks
#   false = Prompt for new disks (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
# print_success "Disabled Time Machine new disk prompts"

################################################################################
# ACTIVITY MONITOR: MAIN WINDOW                                       [DEFAULT]
################################################################################
#
# Show main window when launching Activity Monitor
#
# Options:
#   true  = Show main window
#   false = Don't show (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
# print_success "Enabled Activity Monitor main window"

################################################################################
# ACTIVITY MONITOR: DOCK ICON                                         [DEFAULT]
################################################################################
#
# What to show in Activity Monitor's Dock icon
#
# Options:
#   0 = Application icon (macOS default)
#   2 = Network usage
#   3 = Disk activity
#   5 = CPU usage
#   6 = CPU history
#
# Your current value: not set (using macOS default: 0)
# Status: Using default - no action needed
#
# defaults write com.apple.ActivityMonitor IconType -int 5
# print_success "Set Activity Monitor Dock icon"

################################################################################
# ACTIVITY MONITOR: SHOW PROCESSES                                     [CUSTOM]
################################################################################
#
# Which processes to display
#
# Options:
#   0   = All processes (macOS default)
#   100 = All processes hierarchically
#   101 = My processes
#   102 = System processes
#   103 = Other user processes
#   104 = Active processes
#   105 = Inactive processes
#   106 = Windowed processes

defaults write com.apple.ActivityMonitor ShowCategory -int 100
print_success "Set Activity Monitor to hierarchical view"

################################################################################
# ACTIVITY MONITOR: SORT COLUMN                                       [DEFAULT]
################################################################################
#
# Default sort column in Activity Monitor
#
# Options: CPUUsage, Memory, Energy, Disk, Network, etc.
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
# defaults write com.apple.ActivityMonitor SortDirection -int 0
# print_success "Set Activity Monitor sort"

################################################################################
# TEXTEDIT: PLAIN TEXT MODE                                           [DEFAULT]
################################################################################
#
# Default format for new TextEdit documents
#
# Options:
#   0 = Plain text (useful for coding)
#   1 = Rich text (macOS default)
#
# Your current value: not set (using macOS default: 1)
# Status: Using default - no action needed
#
# defaults write com.apple.TextEdit RichText -int 0
# print_success "Set TextEdit to plain text mode"

################################################################################
# TEXTEDIT: ENCODING                                                  [DEFAULT]
################################################################################
#
# Text encoding for TextEdit
#
# Options:
#   4 = UTF-8
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults write com.apple.TextEdit PlainTextEncoding -int 4
# defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
# print_success "Set TextEdit to UTF-8"

################################################################################
# PHOTOS: AUTO-OPEN                                                   [DEFAULT]
################################################################################
#
# Prevent Photos from opening when devices are plugged in
#
# Options:
#   true  = Disable auto-open
#   false = Auto-open when device connected (macOS default)
#
# Your current value: not set (using macOS default)
# Status: Using default - no action needed
#
# defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
# print_success "Disabled Photos auto-open"

################################################################################
# APPLY CHANGES
################################################################################

print_header "Restarting affected applications..."

for app in "Activity Monitor" "cfprefsd" "Dock" "Finder" "SystemUIServer"; do
    killall "${app}" &> /dev/null || true
done

print_success "macOS defaults configured!"
echo ""
echo "Note: Some changes may require logout or restart to take effect."
