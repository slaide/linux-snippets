#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r localcode - run opencode on a local model, qwen3-coder-next:q8_0"
    exit 0
fi

OLLAMA_FLASH_ATTENTION=1 OLLAMA_VULKAN=1 ROCR_VISIBLE_DEVICES=-1 ollama serve > ~/localcode.log 2>&1 &
#ollama launch opencode --model qwen3-coder-next:latest
ollama launch opencode --model qwen3:32b
