#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r tmux [session] - Attach to or create a tmux session (default: main)"
    exit 0
fi

session="${1:-main}"

if tmux has-session -t "$session" 2>/dev/null; then
    exec tmux attach-session -t "$session"
else
    exec tmux new-session -s "$session"
fi
