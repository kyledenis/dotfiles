# --------------------------------------------------
# Powerlevel10k instant prompt
# --------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --------------------------------------------------
# Loader
# --------------------------------------------------
ZSH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshrc"
[[ -r "$ZSH_CONFIG" ]] && source "$ZSH_CONFIG"
