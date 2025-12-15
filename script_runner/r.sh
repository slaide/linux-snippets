#!/bin/bash

SCRIPTS_DIR="$(dirname "$(realpath "$0")")"

# No arguments - show help
if [ $# -eq 0 ]; then
    exec "$SCRIPTS_DIR/r-help.sh"
fi

script_name="$1"
shift

# Check for runner command (r-<name>.sh) first, then regular script
script_path="$SCRIPTS_DIR/r-${script_name}.sh"
[ -f "$script_path" ] || script_path="$SCRIPTS_DIR/${script_name}.sh"

if [ -f "$script_path" ]; then
    [ -x "$script_path" ] || chmod +x "$script_path"
    exec "$script_path" "$@"
fi

echo "Error: Script '$script_name' not found." >&2
echo
exec "$SCRIPTS_DIR/r-help.sh"
