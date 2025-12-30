# ============================================================================
# .zshenv - Environment Variables
# ============================================================================
# This file is sourced by all shells (login, interactive, and non-interactive)
# Place environment variables here, not in .zshrc

# XDG Base Directory Specification
# ============================================================================
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# Default Editor
# ============================================================================
if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
    export VISUAL="nvim"
elif command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
    export VISUAL="vim"
else
    export EDITOR="nano"
    export VISUAL="nano"
fi

# Language and Locale
# ============================================================================
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Path Configuration
# ============================================================================
# Create array of paths to add
typeset -U path  # Ensure unique entries

# Homebrew (Apple Silicon)
path=("/opt/homebrew/bin" "/opt/homebrew/sbin" $path)

# User binaries
path=("$HOME/.local/bin" $path)

# Cargo (Rust)
if [ -d "$HOME/.cargo/bin" ]; then
    path=("$HOME/.cargo/bin" $path)
fi

# Go
if [ -d "$HOME/go/bin" ]; then
    path=("$HOME/go/bin" $path)
    export GOPATH="$HOME/go"
fi

# Python
if [ -d "$HOME/.local/share/pipx/venvs" ]; then
    path=("$HOME/.local/bin" $path)
fi

# Node (NVM)
export NVM_DIR="$HOME/.nvm"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
path=("$PNPM_HOME" $path)

# Docker
if [ -d "$HOME/.docker/bin" ]; then
    path=("$HOME/.docker/bin" $path)
fi

# History Configuration
# ============================================================================
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
export HISTSIZE=100000
export SAVEHIST=100000

# Create history directory if it doesn't exist
if [ ! -d "$(dirname "$HISTFILE")" ]; then
    mkdir -p "$(dirname "$HISTFILE")"
fi

# Development Tools
# ============================================================================

# Python
export PYTHONDONTWRITEBYTECODE=1  # Don't create .pyc files
export PYTHONUNBUFFERED=1         # Force stdout/stderr to be unbuffered

# Node.js
export NODE_REPL_HISTORY="${XDG_DATA_HOME:-$HOME/.local/share}/node_repl_history"

# NPM
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/npm"

# Docker
export DOCKER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/docker"

# Rust
export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

# AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aws/credentials"

# Terraform
export TF_CLI_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/terraform/terraformrc"

# Less (pager)
# ============================================================================
export LESS='-R -i -M -F -X -z-4'
export LESS_TERMCAP_mb=$'\E[1;31m'     # Begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # Begin blink
export LESS_TERMCAP_me=$'\E[0m'        # Reset bold/blink
export LESS_TERMCAP_so=$'\E[01;33m'    # Begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # Reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # Begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # Reset underline

# FZF Configuration
# ============================================================================
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --inline-info --preview-window=right:60%"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Bat (cat replacement)
# ============================================================================
export BAT_THEME="gruvbox-dark"
export BAT_STYLE="numbers,changes,header"

# Homebrew
# ============================================================================
export HOMEBREW_NO_ANALYTICS=1        # Disable analytics
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS="--require-sha"

# GPG
# ============================================================================
export GPG_TTY=$(tty)

# SSH Agent (1Password)
# ============================================================================
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# PARAS System
# ============================================================================
export PARAS_ROOT="$HOME/Documents/paras"
export PROJECTS_DIR="$PARAS_ROOT/00-projects"
export AREAS_DIR="$PARAS_ROOT/01-areas"
export RESOURCES_DIR="$PARAS_ROOT/02-resources"
export ARCHIVE_DIR="$PARAS_ROOT/03-archive"
export SYSTEM_DIR="$PARAS_ROOT/04-system"

# macOS Specific
# ============================================================================
# Disable Apple Analytics
export HOMEBREW_NO_ANALYTICS=1

# Application-Specific Settings
# ============================================================================
# Jupyter
export JUPYTER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jupyter"

# Wget
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wget/wgetrc"

# Gradle
export GRADLE_USER_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gradle"

# Poetry (Python)
export POETRY_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/poetry"
export POETRY_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/poetry"
export POETRY_VIRTUALENVS_IN_PROJECT=true
