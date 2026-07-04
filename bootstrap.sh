#!/usr/bin/env bash
# One-liner entry point:
#   curl -fsSL https://raw.githubusercontent.com/el/dotfiles/master/bootstrap.sh | bash
#
# Clones the repo to ~/dotfiles, or updates the clone if it's
# already there, then hands off to install.sh. install.sh reads its menu
# keys from /dev/tty, so the picker stays interactive even though this
# script arrives through a pipe. Pass args through with:
#   curl ... | bash -s -- --all
set -euo pipefail

REPO_URL="https://github.com/el/dotfiles.git"
DEST="${DOTFILES_DEST:-$HOME/dotfiles}"

if ! command -v git >/dev/null; then
	if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null; then
		echo "==> Installing git..."
		sudo apt-get update && sudo apt-get install -y git
	else
		echo "!! git is required first (on macOS run: xcode-select --install)" >&2
		exit 1
	fi
fi

if [ -d "$DEST/.git" ]; then
	echo "==> Updating existing clone at $DEST..."
	git -C "$DEST" pull --ff-only ||
		echo "!! Could not fast-forward (local changes?) — continuing with the current version."
else
	echo "==> Cloning to $DEST..."
	mkdir -p "$(dirname "$DEST")"
	git clone "$REPO_URL" "$DEST"
fi

exec bash "$DEST/install.sh" "$@"
