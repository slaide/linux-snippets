#!/bin/bash

SESSION_NAME=${1:-main}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "$SESSION_NAME"
else
    tmux new-session -d -s "$SESSION_NAME" -c ~
    tmux new-window -t "$SESSION_NAME" -c ~ 'echo "
tmux cheat sheet:
C-b %        vertical split (side by side)
C-b \"       horizontal split (top/bottom)
C-b o        switch between panes
C-b arrow    navigate panes with arrows
C-b x        close pane
C-b c        new window/tab
C-b n        next window
C-b p        previous window
C-b ,        rename window
C-b <        move window left
C-b >        move window right
C-b s        list/switch sessions
C-b d        detach from session
C-b $        rename current session
C-b ?        full help

C-b : commands (type after C-b :):
new-session                            create new session
new-window                             create new window
rename-window                          rename current window
select-window                          switch to window by number
attach-session                         attach to session
kill-session                           kill current session
list-sessions                          show all sessions
source-file ~/.tmux.conf               reload config
resize-pane -L 5                       resize pane left 5 cells
resize-pane -R 5                       resize pane right 5 cells
set-window-option automatic-rename off keep custom window names
" | less'
    tmux rename-window -t "$SESSION_NAME":1 "help"
    tmux select-window -t "$SESSION_NAME":0
    tmux attach-session -t "$SESSION_NAME"
fi
