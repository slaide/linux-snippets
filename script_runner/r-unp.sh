#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r unp <archive> - Unpack password-protected archive and remove on success"
    exit 0
fi

# Bash completion function
if [ -n "$R_SCRIPT_COMPLETE" ]; then
    # $1 is the current word being completed
    compgen -f -- "$1" | grep -E '\.(zip|7z|rar|tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz|tar)$' | while read -r f; do printf '%q\n' "$f"; done
    exit 0
fi

if [ $# -eq 0 ]; then
    echo "Usage: r unp <archive>"
    echo "Unpacks a password-protected archive and removes it on success."
    exit 1
fi

archive="$(realpath "$1")"
dest_dir="$(dirname "$archive")"

if [ ! -f "$archive" ]; then
    echo "Error: File '$1' not found." >&2
    exit 1
fi

# Detect archive type and set list/extraction commands
case "${archive,,}" in
    *.tar.gz|*.tgz)
        list_cmd() { tar tzf "$1"; }
        extract_cmd() { tar xzf "$1"; }
        needs_password=false
        ;;
    *.tar.bz2|*.tbz2)
        list_cmd() { tar tjf "$1"; }
        extract_cmd() { tar xjf "$1"; }
        needs_password=false
        ;;
    *.tar.xz|*.txz)
        list_cmd() { tar tJf "$1"; }
        extract_cmd() { tar xJf "$1"; }
        needs_password=false
        ;;
    *.tar)
        list_cmd() { tar tf "$1"; }
        extract_cmd() { tar xf "$1"; }
        needs_password=false
        ;;
    *.zip)
        list_cmd() { unzip -l "$1" | awk 'NR>3 && NF>3 {print $4}'; }
        extract_cmd() { unzip -P "$password" "$1"; }
        needs_password=true
        ;;
    *.rar)
        list_cmd() { unrar lb "$1"; }
        extract_cmd() { unrar x -p"$password" "$1"; }
        needs_password=true
        ;;
    *.7z)
        list_cmd() { 7z l -slt "$1" | grep "^Path = " | cut -d' ' -f3-; }
        extract_cmd() { 7z x -p"$password" -y "$1"; }
        needs_password=true
        ;;
    *)
        echo "Error: Unsupported archive format." >&2
        echo "Supported: .zip, .rar, .7z, .tar, .tar.gz, .tar.bz2, .tar.xz" >&2
        exit 1
        ;;
esac

# Security check: scan archive listing for path traversal
echo "Checking archive contents..."
listing=$(list_cmd "$archive" 2>/dev/null)

if echo "$listing" | grep -qE '(^|/)\.\.(/|$)'; then
    echo "Error: Archive contains path traversal (../) - refusing to extract." >&2
    exit 1
fi

if echo "$listing" | grep -qE '^/'; then
    echo "Error: Archive contains absolute paths - refusing to extract." >&2
    exit 1
fi

# Get password if needed
if [ "$needs_password" = true ]; then
    read -s -p "Password: " password
    echo
fi

# Create temp directory for safe extraction
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cd "$tmpdir" || exit 1

# Extract to temp directory
if ! extract_cmd "$archive"; then
    echo
    echo "Extraction failed. Archive kept." >&2
    exit 1
fi

# Security check: verify no symlinks point outside extraction directory
while IFS= read -r -d '' link; do
    target=$(readlink -f "$link" 2>/dev/null)
    if [[ "$target" != "$tmpdir"* ]]; then
        echo "Error: Symlink '$link' points outside extraction directory - refusing to move." >&2
        exit 1
    fi
done < <(find . -type l -print0)

# Move extracted contents to destination
echo
echo "Extraction successful. Moving files..."
mv "$tmpdir"/* "$dest_dir"/ 2>/dev/null || mv "$tmpdir"/.* "$dest_dir"/ 2>/dev/null

echo "Removing archive..."
rm -rf "$archive"
echo "Done."
