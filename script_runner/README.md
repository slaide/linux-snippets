# Script Runner

A simple script runner with bash autocomplete.

## Installation

1. Add the script runner to your PATH in `~/.bashrc`:

```bash
export PATH="$PATH:/path/to/script_runner"
```

2. Create an alias for easier access:

```bash
alias r='/path/to/script_runner/r.sh'
```

3. Enable autocomplete:

```bash
source /path/to/script_runner/r-completion.bash
```

4. Reload your shell:

```bash
source ~/.bashrc
```

## Usage

```bash
r              # Show available commands
r <command>    # Run a command
r unp <file>   # Unpack an archive (with autocomplete)
```

## Adding New Scripts

- `r-<name>.sh` - Runner commands, invoked as `r <name>`
- `<name>.sh` - Regular scripts, invoked as `r <name>`

Scripts can provide help text by handling `R_SCRIPT_GETHELP`:

```bash
if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r mycommand - Description of my command"
    exit 0
fi
```

Scripts can provide custom autocomplete by handling `R_SCRIPT_COMPLETE`:

```bash
if [ -n "$R_SCRIPT_COMPLETE" ]; then
    # $2 is the current word being completed
    compgen -f -- "$2"
    exit 0
fi
```
