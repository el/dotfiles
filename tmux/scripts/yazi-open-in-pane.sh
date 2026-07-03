#!/usr/bin/env bash
# Called from yazi (Ctrl-o) with the hovered file as $1.
# Opens it with $EDITOR in the tmux pane yazi was launched from.
target=$(tmux show-options -gqv @yazi_target_pane)
[ -z "$target" ] && exit 0
tmux send-keys -t "$target" "${EDITOR:-vim} $(printf '%q' "$1")" Enter
tmux select-pane -t "$target"
