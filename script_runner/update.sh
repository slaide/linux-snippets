set -e

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r update - Update system packages (apt, flatpak, claude-code)"
    exit 0
fi

sudo apt update
sudo apt upgrade -fy
sudo apt autoremove -y

flatpak update -y

bun upgrade
sudo npm i -g @openai/codex
