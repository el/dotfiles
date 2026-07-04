#!/usr/bin/env bash
# Bootstraps terminal settings (tmux, yazi, zsh, git) on a new machine.
# Safe to re-run: existing real files are backed up before being replaced
# with symlinks, and every step is idempotent.
#
# macOS: packages come from Homebrew (Brewfile).
# Linux: packages come from apt where available; starship, eza, yazi, and
# the Nerd Font don't reliably exist in apt, so those are fetched directly
# from upstream releases/installers.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "==> Using dotfiles at $DOTFILES_DIR ($OS)"

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
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

elif [ "$OS" = "Linux" ]; then
	echo "==> Installing packages via apt..."
	sudo apt-get update
	sudo apt-get install -y \
		tmux fzf tree micro \
		zsh-autosuggestions zsh-syntax-highlighting \
		curl unzip fontconfig

	case "$(uname -m)" in
	aarch64 | arm64) RUST_TARGET="aarch64-unknown-linux-gnu" ;;
	x86_64) RUST_TARGET="x86_64-unknown-linux-gnu" ;;
	*) RUST_TARGET="" ;;
	esac

	if ! command -v starship &>/dev/null; then
		echo "==> Installing starship (not in apt)..."
		curl -sS https://starship.rs/install.sh | sh -s -- --yes
	fi

	if ! command -v eza &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			echo "==> Installing eza (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${RUST_TARGET}.tar.gz" |
				tar -xz -C "$tmp"
			sudo install -m 755 "$tmp/eza" /usr/local/bin/eza
			rm -rf "$tmp"
		else
			echo "!! Skipping eza: unsupported architecture $(uname -m)"
		fi
	fi

	if ! command -v yazi &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			echo "==> Installing yazi (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${RUST_TARGET}.zip" -o "$tmp/yazi.zip"
			unzip -q "$tmp/yazi.zip" -d "$tmp"
			sudo install -m 755 "$tmp"/yazi-*/yazi "$tmp"/yazi-*/ya /usr/local/bin/
			rm -rf "$tmp"
		else
			echo "!! Skipping yazi: unsupported architecture $(uname -m)"
		fi
	fi

	font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
	if [ ! -d "$font_dir" ]; then
		echo "==> Installing JetBrains Mono Nerd Font (not in apt)..."
		mkdir -p "$font_dir"
		tmp="$(mktemp -d)"
		curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o "$tmp/font.zip"
		unzip -q "$tmp/font.zip" -d "$font_dir"
		rm -rf "$tmp"
		fc-cache -f "$font_dir" || true
	fi

else
	echo "!! Unsupported OS: $OS" >&2
	exit 1
fi

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
link "$DOTFILES_DIR/readline/inputrc" "$HOME/.inputrc"
link "$DOTFILES_DIR/eza/theme.yml" "$HOME/.config/eza/theme.yml"

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
  - If your default login shell isn't zsh, none of the zsh settings above
    will take effect until you switch: chsh -s "$(command -v zsh)"
  - Set your terminal's font to "JetBrainsMono Nerd Font" (needed for icons
    in the tmux status bar and prompt)
  - Start tmux and try: ` Space   (prefix + space opens the keybinding menu)
EOF
