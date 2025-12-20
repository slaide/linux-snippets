#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r help - Show available scripts and commands"
    exit 0
fi

SCRIPTS_DIR="$(dirname "$(realpath "$0")")"

cat <<'EOF'
Script runner

  r <command> [args...]    Run a script
  r                        Show this help

EOF

# Collect all commands with their info
declare -a runner_cmds=()
declare -a runner_descs=()
declare -a other_cmds=()
declare -a other_descs=()
max_len=0

# Collect runner commands (r-* scripts)
for f in "$SCRIPTS_DIR"/r-*.sh; do
    [ -f "$f" ] || continue
    [[ "$f" == */.ignore/* ]] && continue
    name="$(basename "$f" .sh)"
    if grep -q 'R_SCRIPT_GETHELP' "$f" 2>/dev/null; then
        [ -x "$f" ] || chmod +x "$f"
        info=$(R_SCRIPT_GETHELP=1 "$f" 2>/dev/null)
        cmd="${info%% - *}"
        desc="${info#* - }"
    else
        cmd="r ${name#r-}"
        desc=""
    fi
    runner_cmds+=("$cmd")
    runner_descs+=("$desc")
    (( ${#cmd} > max_len )) && max_len=${#cmd}
done

# Collect other scripts
for f in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$f" ] || continue
    [[ "$f" == */.ignore/* ]] && continue
    name="$(basename "$f" .sh)"
    [ "$name" = "r" ] && continue
    [[ "$name" == r-* ]] && continue
    if grep -q 'R_SCRIPT_GETHELP' "$f" 2>/dev/null; then
        [ -x "$f" ] || chmod +x "$f"
        info=$(R_SCRIPT_GETHELP=1 "$f" 2>/dev/null)
        cmd="${info%% - *}"
        desc="${info#* - }"
    else
        cmd="r $name"
        desc=""
    fi
    other_cmds+=("$cmd")
    other_descs+=("$desc")
    (( ${#cmd} > max_len )) && max_len=${#cmd}
done

# Print runner commands
echo "Runner commands:"
for i in "${!runner_cmds[@]}"; do
    printf "  %-${max_len}s   %s\n" "${runner_cmds[$i]}" "${runner_descs[$i]}"
done

# Print other scripts
echo
echo "Other scripts:"
for i in "${!other_cmds[@]}"; do
    printf "  %-${max_len}s   %s\n" "${other_cmds[$i]}" "${other_descs[$i]}"
done
