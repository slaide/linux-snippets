# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Deduplicate Bash history
HISTCONTROL=ignoredups:ignoreboth

# colorize common commands
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# -- measure last command runtime
function timer_start {
  timer=${timer:-$SECONDS}
}

function timer_stop {
  timer_show=$(($SECONDS - $timer))
  unset timer
}

trap 'timer_start' DEBUG
PROMPT_COMMAND=timer_stop
# -- end ; timer_show within PS1 now contains number of seconds taken by last command

# Define a custom Bash prompt with execution time and exit code
PS1='\[\033[1;32m\]\u\[\033[00m\]:\[\033[1;34m\]\w \[\033[0m\]${timer_show}s $(if [ $? -eq 0 ]; then echo "\[\033[32m\]✔"; else echo "\[\033[31m\]✘($?)"; fi)\[\033[0m\] $ '
