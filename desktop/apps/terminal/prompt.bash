# ── Powerline prompt (truecolor) ────────────────────────────────────────────
# Two-line prompt built per-render in __set_ps1 (via PROMPT_COMMAND):
#   line 1 = a powerline info bar of filled, blended segments —
#            blue \u  violet \h  red \w  green git — using JetBrains Mono's
#            Powerline glyphs ( separator,  branch).
#   line 2 = a clean  prompt whose color shows the last exit status
#            (green = ok, red = failed).
# Same color palette as the old prompt; only the shape/glyphs are new.

# Current branch (or 7-char hash on detached HEAD) into $b; empty when not in a repo.
# Pure bash, no fork: it reads .git/HEAD directly (also follows a ".git" *file*
# for worktrees/submodules). 2026-09-11: replaced `git symbolic-ref` + `$(...)`,
# which cost 2-6 ms per prompt — longer than one 240 Hz frame, so Ghostty's
# cursor-trail shader saw Enter as two separate hops (newline, then prompt) and
# the new-line move looked like a teleport. Now ~0.1 ms.
__pl_branch() {
    b=
    local d=$PWD gd head
    while :; do
        if [ -d "$d/.git" ]; then gd=$d/.git
        elif [ -f "$d/.git" ]; then
            read -r _ gd < "$d/.git" || return          # "gitdir: <path>"
            [ "${gd:0:1}" = / ] || gd=$d/$gd
        else
            [ -z "$d" ] && return                        # reached / without a repo
            d=${d%/*}; continue
        fi
        read -r head < "$gd/HEAD" 2>/dev/null || return
        case $head in
            "ref: refs/heads/"*) b=${head#ref: refs/heads/} ;;
            *)                   b=${head:0:7} ;;
        esac
        return
    done
}

# Append one segment to $out. $1 = "R;G;B" background, $2 = visible text, $3 = optional "R;G;B" text colour.
# Relies on bash dynamic scope for $out / $prevbg / $sep / $txt from __set_ps1.
__pl_seg() {
    if [ -n "$prevbg" ]; then                 # blend: arrow fg = prev bg, bg = new bg
        out+="\[\e[38;2;${prevbg};48;2;${1}m\]${sep}"
    else
        out+="\[\e[48;2;${1}m\]"
    fi
    out+="\[\e[38;2;${3:-$txt}m\] ${2} "
    prevbg=$1
}

__set_ps1() {
    local ec=$?
    local sep=$'' gb=$'' arr=$'❯'
    # Glass theme (2026-09-18): one light tile for the user, then steps down into the dark glass — no accent colours.
    local txt='22;23;24'                        # dark text on the light segments
    local lt='239;240;241'                      # light text on the dark segments
    # accent (2026-09-18): wallpaper blue (light navy) #4c6ed6 on the first tile and the OK arrow; everything else stays glass
    local c_user='76;110;214' c_host='169;172;175'
    local c_path='69;72;76'   c_git='44;46;49'
    local out prevbg= b
    out='\[\e]0;\u@\h: \w\a\]'                  # window/tab title = user@host: dir
    __pl_seg "$c_user" '\u' "$lt"
    __pl_seg "$c_host" '\h'
    __pl_seg "$c_path" '\w' "$lt"
    __pl_branch
    [ -n "$b" ] && __pl_seg "$c_git" "${gb} ${b}" "$lt"
    out+="\[\e[0m\e[38;2;${prevbg}m\]${sep}\[\e[0m\]"   # end cap on default bg
    if [ "$ec" -eq 0 ]; then
        out+=$'\n'"\[\e[38;2;76;110;214m\]${arr}\[\e[0m\] "
    else
        out+=$'\n'"\[\e[38;2;229;72;77m\]${arr}\[\e[0m\] "
    fi
    PS1=$out
}

if [ "$color_prompt" = yes ]; then
    PROMPT_COMMAND=__set_ps1
