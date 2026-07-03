#!/usr/bin/env bash
# Bootstraps terminal settings (tmux, yazi, zsh, git) on a new machine.
# Safe to re-run: existing real files are backed up before being replaced
# with symlinks, and every step is idempotent.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Using dotfiles at $DOTFILES_DIR"

# ---------------------------------------------------------------------------
# 1. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
	echo "==> Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [ -x /usr/local/bin/brew ]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
fi

echo "==> Installing packages via Homebrew Bundle..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# ---------------------------------------------------------------------------
# 2. Symlink config files (backing up any real file already in place)
# ---------------------------------------------------------------------------
link() {
	local src="$1" dest="$2"
	mkdir -p "$(dirname "$dest")"
	if [ -e "$dest" ] && [ ! -L "$dest" ]; then
		local backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
		mv "$dest" "$backup"
		echo "  backed up existing $dest -> $backup"
	fi
	ln -sfn "$src" "$dest"
	echo "  linked $dest -> $src"
}

echo "==> Symlinking config files..."
link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
link "$DOTFILES_DIR/tmux/scripts" "$HOME/.config/tmux/scripts"
link "$DOTFILES_DIR/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml"

# ---------------------------------------------------------------------------
# 3. zsh: source our snippet from ~/.zshrc without touching the rest of it
# ---------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="[ -f \"$DOTFILES_DIR/zsh/zshrc.dotfiles\" ] && source \"$DOTFILES_DIR/zsh/zshrc.dotfiles\""
touch "$ZSHRC"
if ! grep -qF "zshrc.dotfiles" "$ZSHRC"; then
	{
		echo ""
		echo "# Load shared dotfiles settings"
		echo "$SOURCE_LINE"
	} >>"$ZSHRC"
	echo "==> Added dotfiles source line to $ZSHRC"
else
	echo "==> $ZSHRC already sources dotfiles, skipping"
fi

# ---------------------------------------------------------------------------
# 4. git
# ---------------------------------------------------------------------------
echo "==> Setting git core.editor..."
git config --global core.editor "micro"

# ---------------------------------------------------------------------------
# 5. tmux plugins (TPM)
# ---------------------------------------------------------------------------
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
	echo "==> Installing TPM..."
	git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

echo "==> Installing tmux plugins..."
TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins/" "$TPM_DIR/bin/install_plugins"

cat <<'EOF'

==> Done!

Next steps:
  - Open a new terminal (or run: source ~/.zshrc)
  - Set your terminal's font to "JetBrainsMono Nerd Font" (needed for icons
    in the tmux status bar) — e.g. in iTerm2: Preferences > Profiles > Text
  - Start tmux and try: ` Space   (prefix + space opens the keybinding menu)
EOF
