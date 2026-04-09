#!/usr/bin/env bash

################################################################################
# ssh-create.sh - Create and register SSH keys for the dotfiles system
#
# Generates an ed25519 key pair, registers the public key in stow, and guides
# through 1Password import. For known git hosts (GitHub, Bitbucket, GitLab),
# automatically configures SSH config. For other services, creates the key
# and lets you configure the host entry later once you have the server address.
#
# Usage:
#   ssh-create <name>
#   ssh-create github-newproject
#   ssh-create hetzner-my-server
#   ssh-create --host git.company.com work-server
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
STOW_DIR="$DOTFILES_DIR/stow"
SSH_STOW_DIR="$STOW_DIR/ssh/.ssh"
KEYS_DIR="$SSH_STOW_DIR/keys"
SSH_CONFIG="$SSH_STOW_DIR/config"

################################################################################
# Helper Functions
################################################################################

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}→${NC} ${BOLD}$1${NC}"
}

add_ssh_config() {
    local host="$1"
    local user="${2:-root}"

    cat >> "$SSH_CONFIG" << EOF

Host $KEY_NAME
  HostName $host
  User $user
  IdentityFile ~/.ssh/keys/$KEY_NAME.pub
EOF

    cd "$STOW_DIR"
    stow -R ssh
    cd "$DOTFILES_DIR"
    git add "stow/ssh/.ssh/config"
}

show_usage() {
    cat << 'EOF'
Usage: ssh-create [options] <name>

Create a new SSH key and register it in the dotfiles system.

The name should follow the format <service>-<identifier>, e.g.:
  github-personal, hetzner-my-server, bitbucket-work

Arguments:
    name            Key name in <service>-<identifier> format

Options:
    --comment TEXT  Comment for the key (default: auto-generated)
    --host HOST    Specify hostname (auto-detected for github/bitbucket/gitlab)
    --help         Show this help message

For known git hosts (github, bitbucket, gitlab), the hostname is resolved
automatically and an SSH config entry is added. For everything else, the
key is created without a config entry — you can add one later once you
have the server address.

Examples:
    ssh-create github-newproject       # auto-configures github.com
    ssh-create hetzner-my-server       # creates key, no config entry
    ssh-create --host git.company.com work-server

EOF
}

resolve_hostname() {
    local name="$1"
    local prefix="${name%%-*}"

    case "$prefix" in
        github)     echo "github.com" ;;
        bitbucket)  echo "bitbucket.org" ;;
        gitlab)     echo "gitlab.com" ;;
        *)          echo "" ;;
    esac
}

################################################################################
# Temp Directory & Cleanup
################################################################################

TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT INT TERM

################################################################################
# Parse Arguments
################################################################################

COMMENT=""
HOST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --comment)
            COMMENT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

KEY_NAME="$1"

if [[ -z "$KEY_NAME" ]]; then
    print_error "No key name provided"
    show_usage
    exit 1
fi

# Validate name format
if [[ ! "$KEY_NAME" =~ ^[a-zA-Z0-9]+-[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]]; then
    print_error "Invalid key name format: $KEY_NAME"
    echo "  Expected format: <service>-<identifier> (e.g., github-personal)"
    exit 1
fi

# Resolve hostname (empty means unknown — skip config entry)
if [[ -z "$HOST" ]]; then
    HOST=$(resolve_hostname "$KEY_NAME")
fi

# Default comment
if [[ -z "$COMMENT" ]]; then
    if [[ -n "$HOST" ]]; then
        COMMENT="git@${HOST}"
    else
        COMMENT="$KEY_NAME"
    fi
fi

################################################################################
# Duplicate Checks
################################################################################

KEY_EXISTS=false
CONFIG_EXISTS=false

if [[ -f "$KEYS_DIR/$KEY_NAME.pub" ]]; then
    KEY_EXISTS=true
fi

if grep -q "^Host ${KEY_NAME}$" "$SSH_CONFIG" 2>/dev/null; then
    CONFIG_EXISTS=true
fi

# If both exist, nothing to do
if $KEY_EXISTS && $CONFIG_EXISTS; then
    print_error "Key '$KEY_NAME' is already fully configured"
    exit 1
fi

# If key exists but no config — jump straight to adding the config entry
if $KEY_EXISTS && ! $CONFIG_EXISTS; then
    echo ""
    print_info "Key '$KEY_NAME' already exists — just needs an SSH config entry."
    echo ""
    echo -n "  Server address (IP or domain): "
    read -r HOST_ADDR
    echo -n "  SSH user (default: root): "
    read -r HOST_USER
    HOST_USER="${HOST_USER:-root}"

    if [[ -z "$HOST_ADDR" ]]; then
        print_error "No address provided"
        exit 1
    fi

    add_ssh_config "$HOST_ADDR" "$HOST_USER"
    print_success "Added 'Host $KEY_NAME' → $HOST_ADDR to SSH config"
    echo ""
    echo -e "  Connect: ${DIM}ssh $KEY_NAME${NC}"
    echo -e "  Commit:  ${DIM}dotfiles commit 'feat(ssh): add $KEY_NAME config'${NC}"
    echo ""
    exit 0
fi

################################################################################
# Confirmation
################################################################################

echo ""
print_info "This will create an ed25519 SSH key called ${BOLD}$KEY_NAME${NC}"
echo ""
echo "  Comment:       $COMMENT"
echo "  Public key:    ~/.ssh/keys/$KEY_NAME.pub"
if [[ -n "$HOST" ]]; then
    echo "  SSH config:    Host $KEY_NAME → $HOST (auto-configured)"
else
    echo "  SSH config:    None yet (add later when you have the server address)"
fi
echo ""

read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Aborted"
    exit 0
fi

################################################################################
# Generate Key
################################################################################

TEMP_DIR=$(mktemp -d)

print_step "Generating key pair"
ssh-keygen -t ed25519 -C "$COMMENT" -f "$TEMP_DIR/$KEY_NAME" -N "" -q
print_success "Key pair generated in temp directory"

################################################################################
# Install Public Key
################################################################################

print_step "Registering public key in dotfiles"
mkdir -p "$KEYS_DIR"
cp "$TEMP_DIR/$KEY_NAME.pub" "$KEYS_DIR/$KEY_NAME.pub"
chmod 600 "$KEYS_DIR/$KEY_NAME.pub"
print_success "Copied to stow/ssh/.ssh/keys/$KEY_NAME.pub"

if [[ -n "$HOST" ]]; then
    print_step "Configuring SSH host alias"
    add_ssh_config "$HOST" "git"
    print_success "Added 'Host $KEY_NAME' → $HOST to SSH config"
fi

################################################################################
# Re-stow
################################################################################

print_step "Updating symlinks"
cd "$STOW_DIR"
stow -R ssh
print_success "Stow re-linked ssh package"

################################################################################
# Git Stage
################################################################################

print_step "Staging for commit"
cd "$DOTFILES_DIR"
git add "stow/ssh/.ssh/keys/$KEY_NAME.pub"
if [[ -n "$HOST" ]]; then
    git add "stow/ssh/.ssh/config"
fi
print_success "Changes staged in dotfiles repo"

################################################################################
# Copy Public Key
################################################################################

echo ""
read -p "Copy public key to clipboard? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pbcopy < "$KEYS_DIR/$KEY_NAME.pub"
    print_success "Public key copied to clipboard"
fi

################################################################################
# 1Password Import
################################################################################

print_step "Import private key to 1Password"
echo ""
echo "  1. Open 1Password → click '+' → Import → select the private key file:"
echo ""
echo -e "     ${BOLD}$TEMP_DIR/$KEY_NAME${NC}"
echo ""
echo -e "  2. Name it: ${BOLD}$KEY_NAME${NC}"
echo -e "  3. Save to a vault listed in ${DIM}~/.config/1Password/ssh/agent.toml${NC}"
echo -e "     (currently: Work, Sensitive)"
echo ""
print_warning "Keys in unlisted vaults won't be served by the 1Password SSH agent."
print_warning "The private key will be DELETED from disk when you continue."
echo ""
read -p "Press Enter after importing to 1Password (or Ctrl-C to abort)... "

################################################################################
# Configure SSH host (if not already done)
################################################################################

if [[ -z "$HOST" ]]; then
    echo ""
    echo -n "Do you have the server address yet? (y/n) "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -n "  Server address (IP or domain): "
        read -r HOST_ADDR
        echo -n "  SSH user (default: root): "
        read -r HOST_USER
        HOST_USER="${HOST_USER:-root}"

        if [[ -n "$HOST_ADDR" ]]; then
            print_step "Configuring SSH host alias"
            add_ssh_config "$HOST_ADDR" "$HOST_USER"
            print_success "Added 'Host $KEY_NAME' → $HOST_ADDR to SSH config"
            HOST="$HOST_ADDR"
        fi
    fi
fi

################################################################################
# Done
################################################################################

echo ""
print_success "SSH key '$KEY_NAME' created and registered."
echo ""
echo "  Next steps:"
if [[ -n "$HOST" ]]; then
    echo "    1. Add the public key to your $HOST account (if not already done)"
    echo -e "    2. Test: ${DIM}ssh $KEY_NAME${NC}"
    echo -e "    3. Commit: ${DIM}dotfiles commit 'feat(ssh): add $KEY_NAME key'${NC}"
else
    echo "    1. Paste the public key into your provider"
    echo -e "    2. When you have the server address, run: ${DIM}ssh-create $KEY_NAME${NC}"
    echo -e "    3. Commit: ${DIM}dotfiles commit 'feat(ssh): add $KEY_NAME key'${NC}"
fi
echo ""

# Cleanup happens automatically via trap
