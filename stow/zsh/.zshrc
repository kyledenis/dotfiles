# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("/Users/kyledenis/.zsh/completions" $fpath)
autoload -Uz compinit
compinit
# OPENSPEC:END

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

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/kyledenis/.lmstudio/bin"
# End of LM Studio CLI section

