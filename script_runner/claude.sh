#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r claude - Run Claude Code with permissions skipped"
    exit 0
fi

claude --dangerously-skip-permissions
