alias p="print -l"

# For mac, aliases
if is_osx; then
    has "qlmanage" && alias ql='qlmanage -p "$@" >&/dev/null'
    alias gvim="open -a MacVim"
fi

if has 'git'; then
    alias gst='git status'
fi

if has 'richpager'; then
    alias cl='richpager'
fi

if (( $+commands[gls] )); then
    alias ls='gls -F --color --group-directories-first'
elif (( $+commands[ls] )); then
    if is_osx; then
        alias ls='ls -GF'
    else
    alias ls='ls -F --color'
    fi
fi

# Common aliases
alias ..='cd ..'
alias ld='ls -ld'          # Show info about the directory
alias lla='ls -lAF'        # Show hidden all files
alias ll='ls -lF'          # Show long file information
alias la='ls -AF'          # Show hidden files
alias lx='ls -lXB'         # Sort by extension
alias lk='ls -lSr'         # Sort by size, biggest last
alias lc='ls -ltcr'        # Sort by and show change time, most recent last
alias lu='ls -ltur'        # Sort by and show access time, most recent last
alias lt='ls -ltr'         # Sort by date, most recent last
alias lr='ls -lR'          # Recursive ls

# The ubiquitous 'll': directories first, with alphanumeric sorting:
#alias ll='ls -lv --group-directories-first'

alias cp="${ZSH_VERSION:+nocorrect} cp -i"
alias mv="${ZSH_VERSION:+nocorrect} mv -i"
alias mkdir="${ZSH_VERSION:+nocorrect} mkdir"

autoload -Uz zmv
alias zmv='noglob zmv -W'

alias du='du -h'
alias job='jobs -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Use if colordiff exists
if has 'colordiff'; then
    alias diff='colordiff -u'
else
    alias diff='diff -u'
fi

alias vi="vim"

# Use plain vim.
alias nvim='vim -N -u NONE -i NONE'

# The first word of each simple command, if unquoted, is checked to see 
# if it has an alias. [...] If the last character of the alias value is 
# a space or tab character, then the next command word following the 
# alias is also checked for alias expansion
alias sudo='sudo '
if is_osx; then
    alias sudo="${ZSH_VERSION:+nocorrect} sudo "
fi

# Global aliases
alias -g G='| grep'
alias -g GG='| multi_grep'
alias -g W='| wc'
alias -g X='| xargs'
alias -g F='| "$(available $INTERACTIVE_FILTER)"'
alias -g S="| sort"
alias -g V="| tovim"
alias -g N=" >/dev/null 2>&1"
alias -g N1=" >/dev/null"
alias -g N2=" 2>/dev/null"
alias -g VI='| xargs -o vim'

multi_grep() {
    local std_in="$(cat <&0)" word

    for word in "$@"
    do
        std_in="$(echo "${std_in}" | command grep "$word")"
    done

    echo "${std_in}"
}

(( $+galiases[H] )) || alias -g H='| head'
(( $+galiases[T] )) || alias -g T='| tail'

if has "emojify"; then
    alias -g E='| emojify'
fi

if has "jq"; then
    alias -g JQ='| jq -C .'
    alias -g JL='| jq -C . | less -R -X'
fi

if is_osx; then
    alias -g CP='| pbcopy'
    alias -g CC='| tee /dev/tty | pbcopy'
fi

cat_alias() {
    local i stdin file=0
    stdin=("${(@f)$(cat <&0)}")
    for i in "${stdin[@]}"
    do
        if [[ -f $i ]]; then
            cat "$@" "$i"
            file=1
        fi
    done
    if [[ $file -eq 0 ]]; then
        echo "${(F)stdin}"
    fi
}
alias -g C="| cat_alias"

# less
alias -g L="| cat_alias | less"
alias -g LL="| less"

pygmentize_alias() {
    if has "pygmentize"; then
        local get_styles styles style
        get_styles="from pygments.styles import get_all_styles
        styles = list(get_all_styles())
        print('\n'.join(styles))"
        styles=( $(sed -e 's/^  *//g' <<<"$get_styles" | python) )

        style=${${(M)styles:#solarized}:-default}
        cat_alias "$@" | pygmentize -O style="$style" -f console256 -g
    else
        cat -
    fi
}
alias -g P="| pygmentize_alias"

awk_alias() {
    autoload -Uz is-at-least
    if ! is-at-least 5; then
        return 1
    fi

    local -a opts
    local    field=0 pattern

    while (( $# > 0 ))
    do
        case "$1" in
            -*|--*)
                opts+=( "$1" )
                ;;
            *)
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    field="$1"
                else
                    pattern="$1"
                fi
                ;;
        esac
        shift
    done

    if ! awk ${=opts[@]} "$"$field" ~ $pattern{print $"$field"}" 2>/dev/null; then
        printf "Galias: syntax error\n"
        return 1
    fi
}

awk_alias2() {
    local -a options fields words
    while (( $#argv > 0 ))
    do
        case "$1" in
            -*)
                options+=("$1")
                ;;
            <->)
                fields+=("$1")
                ;;
            *)
                words+=("$1")
                ;;
        esac
        shift
    done
    if (( $#fields > 0 )) && (( $#words > 0 )); then
        awk '$'$fields[1]' ~ '${(qqq)words[1]}''
    elif (( $#fields > 0 )) && (( $#words == 0 )); then
        awk '{print $'$fields[1]'}'
    fi
}
alias -g A="| awk_alias2"

mru() {
    local -a f1 f2 f2_backup
    f1=(
    ~/.vim_mru_files(N)
    ~/.unite/file_mru(N)
    ~/.cache/ctrlp/mru/cache.txt(N)
    ~/.frill(N)
    )
    f2=($DOTPATH/**/*~$DOTPATH/*\.git/**(.N))
    if [[ $#f1 -eq 0 || $#f2 -eq 0 ]]; then
        echo "There is no available MRU Vim plugins" >&2
        return 1
    fi

    local cmd q k res
    local line ok make_dir i arr
    local get_styles styles style
    while : ${make_dir:=0}; ok=("${ok[@]:-dummy_$RANDOM}"); cmd="$(
        { if (( $#f1 > 0 )); then cat <$f1; fi; echo "${(F)f2}"; } \
            | while read line; do [ -e "$line" ] && echo "$line"; done \
            | while read line; do [ "$make_dir" -eq 1 ] && echo "${line:h}/" || echo "$line"; done \
            | awk '!a[$0]++' \
            | perl -pe 's/^(\/.*\/)(.*)$/\033[34m$1\033[m$2/' \
            | fzf --ansi --multi --query="$@" \
            --no-sort --prompt="MRU> " \
            --print-query --expect=ctrl-v,ctrl-x,ctrl-l,ctrl-q,ctrl-r,"?",ctrl-z,ctrl-y
            )"; do
        q="$(head -1 <<< "$cmd")"
        k="$(head -2 <<< "$cmd" | tail -1)"
        res="$(sed '1,2d;/^$/d' <<< "$cmd")"
        #[ -z "$res" ] && continue
        case "$k" in
            "?")
                cat <<HELP > /dev/tty
usage: vim_mru_files
    list up most recently files

keybind:
  ctrl-q  output files and quit
  ctrl-l  less files under the cursor
  ctrl-v  vim files under the cursor
  ctrl-r  change view type
  ctrl-x  remove files (two-step)
HELP
                return 1
                ;;
            ctrl-y)
                # Reset ctrl-z
                f1=(
                ~/.vim_mru_files(N)
                ~/.unite/file_mru(N)
                ~/.cache/ctrlp/mru/cache.txt(N)
                ~/.frill(N)
                )
                f2=($f2_backup)
                ;;
            ctrl-z)
                # Enter to the directroy (or parent directory of the file) under the cursor
                f2_backup=($f2)
                make_dir=0
                if [[ -d $res ]]; then
                    f1=()
                    f2=(${res}*(N))
                else
                    f1=()
                    f2=(${res:h}/*(N))
                fi
                ;;
            ctrl-r)
                # show up the parent directories
                if [ $make_dir -eq 1 ]; then
                    make_dir=0
                else
                    make_dir=1
                fi
                continue
                ;;
            ctrl-l)
                # less
                export LESS='-R -f -i -P ?f%f:(stdin). ?lb%lb?L/%L.. [?eEOF:?pb%pb\%..]'
                arr=("${(@f)res}")
                if [[ -d ${arr[1]} ]]; then
                    ls -l "${(@f)res}" < /dev/tty | less > /dev/tty
                else
                    if has "pygmentize"; then
                        get_styles="from pygments.styles import get_all_styles
                        styles = list(get_all_styles())
                        print('\n'.join(styles))"
                        styles=( $(sed -e 's/^  *//g' <<<"$get_styles" | python) )
                        style=${${(M)styles:#solarized}:-default}
                        export LESSOPEN="| pygmentize -O style=$style -f console256 -g %s"
                    fi
                    less "${(@f)res}" < /dev/tty > /dev/tty
                fi
                ;;
            ctrl-x)
                # remove (2-steps)
                if [[ ${(j: :)ok} == ${(j: :)${(@f)res}} ]]; then
                    eval '${${${(M)${+commands[gomi]}#1}:+gomi}:-rm} "${(@f)res}" 2>/dev/null'
                    ok=()
                else
                    ok=("${(@f)res}")
                fi
                ;;
            ctrl-v)
                # vim
                vim -p "${(@f)res}" < /dev/tty > /dev/tty
                ;;
            ctrl-q)
                # quit with echo
                echo "$res" < /dev/tty > /dev/tty
                return $status
                ;;
            *)
                echo "${(@f)res}"
                break
                ;;
        esac
    done
}
alias -g FROM='$(mru)'

destination_directories() {
    local -a d
    if [[ -f $ENHANCD_LOG ]]; then
        d=("${(@f)"$(<$ENHANCD_LOG)"}")
    else
        d=(
        #${GOPATH%%:*}/src/github.com/**/*~**/*\.git/**(N-/)
        $DOTPATH/**/*~$DOTPATH/*\.git/**(N-/)
        $HOME/Dropbox(N-/)
        $HOME
        $OLDPWD
        $($DOTPATH/bin/tfp(N))
        )
    fi
    if [[ $#d -eq 0 ]]; then
        echo "There is no available directory" >&2
        return 1
    fi

    local cmd q k res
    local line make_dir
    while : ${make_dir:=0}; cmd="$(
        echo "${(F)d}" \
            | while read line; do echo "${line:F:$make_dir:h}"; done \
            | reverse | awk '!a[$0]++' | reverse \
            | perl -pe 's/^(\/.*)$/\033[34m$1\033[m/' \
            | fzf --ansi --multi --tac --query="$q" \
            --no-sort --exit-0 --prompt="destination-> " \
            --print-query --expect=ctrl-r,ctrl-y,ctrl-q \
            )"; do
        q="$(head -1 <<< "$cmd")"
        k="$(head -2 <<< "$cmd" | tail -1)"
        res="$(sed '1,2d;/^$/d' <<< "$cmd")"
        [ -z "$res" ] && continue
        case "$k" in
            ctrl-y)
                let make_dir--
                continue
                ;;
            ctrl-r)
                let make_dir++
                continue
                ;;
            ctrl-q)
                echo "${(@f)res}" >/dev/tty
                break
                ;;
            *)
                echo "${(@f)res}"
                break
                ;;
        esac
    done
}
alias -g TO='$(destination_directories)'

uniq_alias() {
    if (( ${ZSH_VERSION%%.*} < 5 )); then
        return
    fi

    local f=0 opt=
    if [[ $# -gt 0 && ${@[-1]} =~ ^[0-9]+$ ]]; then
        f=${@[-1]}
        opt=${@:1:-1}
    fi
    awk $opt '!a[$'"${f:-0}"']++'
}
alias -g U="| uniq_alias"

if has "gomi"; then
    alias -g D="| gomi"
fi

# finder
# alias f='fzf \
#     --bind="ctrl-l:execute(less {})" \
#     --bind="ctrl-h:execute(ls -l {} | less)" \
#     --bind="ctrl-v:execute(vim {})"'
# alias -g F='$(f)'

# list galias
alias galias="alias | command grep -E '^[A-Z]'"

# list git branch
git_branch() {
    is_git_repo || return
    has "fzf"   || return

    {
        git branch | sed -e '/^\*/d'
        git branch | sed -n -e '/^\*/p'
    } \
        | reverse \
        | fzy \
        | sed -e 's/^\*[ ]*//g'
}

alias -g GB='$(git_branch)'

if has "tw"; then
    alias -g TW="| tw --pipe"
    if has "emojify"; then
        alias -g TW="| emojify | tw --pipe"
    fi
fi

git_modified_files() {
    is_git_repo || return

    local cmd q k res ok
    while ok=("${ok[@]:-dummy_$RANDOM}"); cmd="$(
        git status --po \
            | awk '$1=="M"{print $2}' \
            | FZF_DEFAULT_OPTS= fzf --ansi --multi --query="$@" \
            --no-sort --prompt="[C-a:add | C-c:checkout | C-d:diff]> " \
            --print-query --expect=ctrl-d,ctrl-a,ctrl-c \
            --bind=ctrl-z:toggle-all \
            )"; do
        q="$(head -1 <<< "$cmd")"
        k="$(head -2 <<< "$cmd" | tail -1)"
        res="$(sed '1,2d;/^$/d' <<< "$cmd")"
        [ -z "$res" ] && continue
        case "$k" in
            ctrl-c)
                if [[ ${(j: :)ok} == ${(j: :)${(@f)res}} ]]; then
                    git checkout -- "${(@f)res}"
                    ok=()
                else
                    ok=("${(@f)res}")
                fi
                ;;
            ctrl-a)
                git add "${(@f)res}"
                ;;
            ctrl-d)
                git diff "${(@f)res}" < /dev/tty > /dev/tty
                ;;
            *)
                echo "${(@f)res}" < /dev/tty > /dev/tty
                break
                ;;
        esac
    done
}
#alias -g GG='$(git_modified_files)'

# treels() {
#     local -a files=( *(D) )
#     if (( $#files > $LINES )); then
#         tree -C -L 1 -a -I .git
#     else
#         tree -C
#     fi
# }

alias t="tree -C"

alias l="ls -l"

# alias f='fzf --preview="pygmentize {}" --preview-window=right:60% --ansi --bind "enter:execute(vim {})"'

function get_path() {
    local f="${1:?}"
    if [[ -t 1 ]]; then
        # give a new line if stdout
        printf "${f:A}\n"
    else
        printf "${f:A}"
    fi
}

alias p="get_path"

alias hs="command history"

# function kchange() {
#     kubectx $(kubectx | fzy)
# }

alias -g P='$(kubectl get pods | fzf-tmux --header-lines=1 --reverse --multi --cycle | awk "{print \$1}")'
alias -g F='$(fzf-tmux --reverse --multi --cycle)'
alias -g J='| jq -C . | less -F'

function filetime() {
    zmodload "zsh/stat"
    zmodload "zsh/datetime"
    strftime "%F %T" "$(stat +mtime "${1:?}")"
}
