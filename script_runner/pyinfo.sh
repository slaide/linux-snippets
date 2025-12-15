#!/usr/bin/env python3
import os
import sys

if os.getenv("R_SCRIPT_GETHELP"):
    print("r pyinfo - Show Python version and system info")
    sys.exit(0)

print(f"Python {sys.version}")
print(f"Platform: {sys.platform}")
