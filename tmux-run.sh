#!/bin/bash

# helper script to display tmux shortcuts in open tab when opening tmux (via this script)

# open new session called "main"
tmux new-session -d -s main -c .

tmux new-window -t main -c ~ 'echo "
tmux cheat sheet:
C-b %       vertical split (side by side)
C-b \"      horizontal split (top/bottom)
C-b o       switch between panes
C-b arrow   navigate panes with arrows
C-b x       close pane
C-b c       new window/tab
C-b n       next window
C-b p       previous window
C-b ,       rename window
C-b ?       full help
C-b d       detach session
" | less'
tmux select-window -t main:0
tmux attach-session -t main
