#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r codex - Run codex with permissions skipped"
    exit 0
fi

codex --dangerously-bypass-approvals-and-sandbox
