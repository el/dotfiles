#!/usr/bin/env bash
# Called from yazi (Ctrl-g). Sends a "cd" for yazi's current directory
# to the tmux pane yazi was launched from, without stealing focus.
target=$(tmux show-options -gqv @yazi_target_pane)
[ -z "$target" ] && exit 0
tmux send-keys -t "$target" "cd $(printf '%q' "$PWD")" Enter
