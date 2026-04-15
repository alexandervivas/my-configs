# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Which plugins would you like to load?
plugins=(git asdf)

source $ZSH/oh-my-zsh.sh

# Load Powerlevel10k theme (conditional)
if [[ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load zsh-syntax-highlighting (conditional)
if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Load zsh-history-substring-search (conditional)
if [[ -f $(brew --prefix 2>/dev/null)/share/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh
fi

# Load asdf (conditional)
if [[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}" ]]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

# Load asdf Java plugin (conditional)
if [[ -f ~/.asdf/plugins/java/set-java-home.zsh ]]; then
  . ~/.asdf/plugins/java/set-java-home.zsh
fi

# Load direnv (conditional)
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# Source machine-specific configuration
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
