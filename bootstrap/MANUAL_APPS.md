# Manual Application Installation List

Applications from your `/Applications` folder that are **NOT** available via Homebrew and need to be installed manually.

## Download & Install Manually

### Creative & Professional Tools

- **Adobe Lightroom** - https://www.adobe.com/products/photoshop-lightroom.html
  - Requires Adobe Creative Cloud subscription

- **DaVinci Resolve** - https://www.blackmagicdesign.com/products/davinciresolve
  - Free or Studio version

- **Logic Pro X** - Mac App Store (mas install 634148309)
  - Professional music production

- **TouchDesigner** - https://derivative.ca/download
  - Visual programming for interactive media

### Utilities & Productivity

- **ColorSlurp** - Mac App Store
  - Color picker tool

- **Darkroom** - Mac App Store
  - Photo & video editor

- **Dropover** - https://dropoverapp.com/
  - Shelf for drag & drop

- **Flighty** - Mac App Store
  - Flight tracking

- **Gestimer** - Mac App Store
  - Quick timer tool

- **Gifski** - Mac App Store (mas install 1351639930)
  - GIF converter

- **KeyKey** - https://keykey.ninja/
  - Typing practice tool

- **Klack** - https://tryklack.com/
  - Mechanical keyboard sounds

- **Opal** - https://opal.so/
  - Screen time & focus tool

- **Overcast** - Mac App Store
  - Podcast player

- **Pixe** - https://poolsuite.net/
  - Poolsuite FM desktop app

- **Play** - https://www.getplayapp.com/
  - Design previewer

- **Reeder** / **Reeder 2** - Mac App Store
  - RSS reader

- **SmartGym** - Mac App Store
  - Workout tracker

- **Tripsy** - Mac App Store
  - Travel planner

- **Wispr Flow** - https://wisprflow.com/
  - Voice-to-text tool

### Development & Tech

- **Burp Suite Community Edition** - https://portswigger.net/burp/communitydownload
  - Note: Professional version is in Homebrew

- **Dia** - http://dia-installer.de/
  - Diagram editor

- **FileZilla** - https://filezilla-project.org/download.php
  - FTP client

- **Rive Early Access** - https://rive.app/
  - Animation tool (early access version)

- **WireGuard** - Mac App Store (mas install 1451685025)
  - VPN tool

### Mac App Store Apps

Install these via the App Store or `mas` command:

```bash
# Install mas if not already installed
brew install mas

# Apple Apps
mas install 682658836   # GarageBand
mas install 408981434   # iMovie
mas install 409183694   # Keynote
mas install 409203825   # Numbers
mas install 409201541   # Pages
mas install 634148309   # Logic Pro X
mas install 497799835   # Xcode
mas install 1661733229  # Swift Playgrounds

# Third-Party Apps
mas install 897118787   # Shazam
mas install 1351639930  # Gifski
mas install 1451685025  # WireGuard
# mas install XXXXXXXXX  # ColorSlurp (find ID)
# mas install XXXXXXXXX  # Darkroom (find ID)
# mas install XXXXXXXXX  # Flighty (find ID)
# mas install XXXXXXXXX  # Gestimer (find ID)
# mas install XXXXXXXXX  # Opal (find ID)
# mas install XXXXXXXXX  # Overcast (find ID)
# mas install XXXXXXXXX  # Reeder (find ID)
# mas install XXXXXXXXX  # SmartGym (find ID)
# mas install XXXXXXXXX  # Tripsy (find ID)
```

To find App Store IDs:
```bash
mas search "App Name"
```

### No Longer Needed

- **1Password for Safari** - Extension installed via 1Password app
- **Proton Mail Uninstaller** - Only needed for uninstalling

## Installation Script

You can copy this script to install the Mac App Store apps:

```bash
#!/bin/bash

echo "Installing Mac App Store applications..."

# Ensure mas is installed
if ! command -v mas &> /dev/null; then
    echo "Installing mas..."
    brew install mas
fi

# Apple Apps
echo "Installing Apple apps..."
mas install 682658836   # GarageBand
mas install 408981434   # iMovie
mas install 409183694   # Keynote
mas install 409203825   # Numbers
mas install 409201541   # Pages
mas install 497799835   # Xcode

# Third-Party
echo "Installing third-party apps..."
mas install 897118787   # Shazam
mas install 1351639930  # Gifski
mas install 1451685025  # WireGuard

echo "Complete! Please install remaining apps manually from links above."
```

## Notes

- **Total manual installations needed**: ~30 apps
- **Mac App Store apps**: ~15 apps
- **Download required**: ~15 apps
- Some apps may have been installed via Setapp or other subscription services
- Check if you actually need all these apps before reinstalling on a new machine

---

**Last Updated**: 2024-12-28
