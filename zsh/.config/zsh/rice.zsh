# The rice's zsh: the same in every rice, only the colours follow it.
# Sourced from ~/.zshrc by one line the installer adds:
#   [ -f ~/.config/zsh/rice.zsh ] && source ~/.config/zsh/rice.zsh
# Anything you put in ~/.zshrc after that line wins.

[[ -o interactive ]] || return 0

# ── history and options ───────────────────────────────────────────────────
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS
setopt NO_BEEP
bindkey -e

# ── completion ────────────────────────────────────────────────────────────
# zsh-completions installs into site-functions, which is already on fpath
_rice_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $_rice_cache ]] || mkdir -p "$_rice_cache"
autoload -Uz compinit
compinit -d "$_rice_cache/zcompdump"
zmodload zsh/complist
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$_rice_cache"
# case-insensitive, then -/_ and partial words: "dow" finds Downloads
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:*:kill:*' menu yes select
# Shift+Tab walks the menu backwards
bindkey -M menuselect '^[[Z' reverse-menu-complete
unset _rice_cache

# keys a bare zsh leaves unbound
bindkey '^[[H' beginning-of-line  '^[[F' end-of-line  '^[[3~' delete-char
bindkey '^[[1;5C' forward-word    '^[[1;5D' backward-word
bindkey '^H' backward-kill-word   # Ctrl+Backspace

# ── the rice's colours ────────────────────────────────────────────────────
# reloaded on the next prompt whenever `rice <name>` re-renders it or the mode changes
_rice_colours="${XDG_DATA_HOME:-$HOME/.local/share}/rice/active/zsh.zsh"
_rice_colours_loaded=""
_rice_colours_reload() {
    [[ -r $_rice_colours ]] || return 0
    # which rice and mode (active is a symlink) and when it was last rendered
    local now="${_rice_colours:A} $(zstat +mtime -- "$_rice_colours" 2>/dev/null)"
    [[ $now == "$_rice_colours_loaded" ]] && return 0
    _rice_colours_loaded=$now
    source "$_rice_colours"
}
zmodload -F zsh/stat b:zstat 2>/dev/null
autoload -Uz add-zsh-hook
add-zsh-hook precmd _rice_colours_reload
_rice_colours_reload

# ── plugins (Arch's paths; each is optional) ──────────────────────────────
_rice_plugins=/usr/share/zsh/plugins
if [[ -r $_rice_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30
    source $_rice_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    bindkey '^ ' autosuggest-accept      # Ctrl+Space takes the suggestion (→ does too)
fi
# syntax highlighting has to come after every other widget-wrapping plugin
if [[ -r $_rice_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    source $_rice_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
# Up/Down search history for what's already typed
if [[ -r $_rice_plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source $_rice_plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up    '^[OA' history-substring-search-up
    bindkey '^[[B' history-substring-search-down  '^[OB' history-substring-search-down
fi
unset _rice_plugins

# ── ls with glyphs ────────────────────────────────────────────────────────
if (( $+commands[eza] )); then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --group-directories-first --git'
    alias la='eza -la --icons=auto --group-directories-first --git'
    alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lAh --color=auto'
fi
alias grep='grep --color=auto'

# ── prompt ────────────────────────────────────────────────────────────────
# ~/.config/starship.toml is the rice's, linked by rice-render
(( $+commands[starship] )) && eval "$(starship init zsh)"
