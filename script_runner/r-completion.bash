# Bash completion for r script runner
# Source this in your .bashrc: source /path/to/r-completion.bash

_r_completion() {
    local cur prev words cword
    _init_completion || return

    local scripts_dir="$(dirname "$(realpath "$(which r 2>/dev/null || echo /home/patrick/code/linux-snippets/script_runner/r.sh)")")"

    # First argument: complete with available commands
    if [ "$cword" -eq 1 ]; then
        local cmds=()
        # Get r-* commands (strip r- prefix)
        for f in "$scripts_dir"/r-*.sh; do
            [ -f "$f" ] || continue
            name="$(basename "$f" .sh)"
            cmds+=("${name#r-}")
        done
        # Get other scripts
        for f in "$scripts_dir"/*.sh; do
            [ -f "$f" ] || continue
            name="$(basename "$f" .sh)"
            [ "$name" = "r" ] && continue
            [[ "$name" == r-* ]] && continue
            cmds+=("$name")
        done
        COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
        return
    fi

    # Second argument onwards: check if the script has its own completion
    local cmd="${words[1]}"
    local script_path="$scripts_dir/r-${cmd}.sh"
    [ -f "$script_path" ] || script_path="$scripts_dir/${cmd}.sh"

    if [ -f "$script_path" ] && grep -q 'R_SCRIPT_COMPLETE' "$script_path" 2>/dev/null; then
        # Script provides its own completion
        COMPREPLY=($(R_SCRIPT_COMPLETE=1 "$script_path" "$cur" "$prev" "${words[@]}"))
    else
        # Default to file completion
        _filedir
    fi
}

complete -F _r_completion r
