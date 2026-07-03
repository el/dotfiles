#!/usr/bin/env bash
# Toggle a yazi file-manager pane on the left of the current tmux window.

pane_id=$(tmux list-panes -F '#{pane_id} #{pane_current_command}' | awk '$2=="yazi"{print $1; exit}')

if [ -n "$pane_id" ]; then
	tmux kill-pane -t "$pane_id"
else
	tmux set-option -g @yazi_target_pane "$(tmux display-message -p '#{pane_id}')"
	tmux split-window -h -b -l 50 -c "#{pane_current_path}" 'yazi'
fi
