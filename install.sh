#!/usr/bin/env bash
# Bootstraps terminal settings (tmux, yazi, zsh, git) on a new machine.
#
# Usage:
#   ./install.sh          interactive menu to pick what to install
#   ./install.sh --all    install everything, no menu
#
# Env:
#   DOTFILES_ALL=1        same as --all
#   DOTFILES_DRY_RUN=1    print what would be installed, change nothing
#
# Safe to re-run: existing real files are backed up before being replaced
# with symlinks, and every step is idempotent.
#
# macOS: packages via Homebrew (installed if missing).
# Linux: packages via apt where reliable; starship, eza, yazi, btop, gdu,
# lazygit, and the Nerd Font aren't reliably in apt repos (or drift across
# distro versions), so those come from upstream releases/installers instead.
#
# Kept bash-3.2 compatible (stock macOS bash): no associative arrays,
# no fractional read timeouts.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ---------------------------------------------------------------------------
# Selection model
# ---------------------------------------------------------------------------
CAT_NAMES=("Terminal & Prompt" "File Tools" "Git & Monitoring" "Tmux" "Zsh" "Other Configs")

ITEM_CATS=(0 1 1 1 1 1 0 0 2 2 2 3 3 4 4 5 5 5 5 5 0 0)
ITEM_IDS=(tmux fzf tree micro yazi eza starship nerd-font
	lazygit btop gdu
	tmux-config tmux-plugins zshrc zsh-plugins
	yazi-config eza-theme btop-theme inputrc git-editor
	pet cheat)
ITEM_LABELS=(
	"tmux — terminal multiplexer"
	"fzf — fuzzy finder"
	"tree — directory listings"
	"micro — terminal editor"
	"yazi — file manager"
	"eza — colorful ls"
	"starship — shell prompt"
	"JetBrainsMono Nerd Font"
	"lazygit — git TUI"
	"btop — system monitor"
	"gdu — disk usage analyzer"
	"tmux.conf + helper scripts"
	"tmux plugins (TPM: theme, resurrect, fzf, ...)"
	".zshrc snippet (EDITOR, prompt, eza aliases)"
	"zsh plugins (autosuggestions, syntax highlighting)"
	"yazi keymap (tmux sidebar integration)"
	"eza Catppuccin theme"
	"btop Catppuccin theme"
	"inputrc (arrow-key history search)"
	"git core.editor = micro"
	"pet — command snippet manager (Ctrl-S to search)"
	"cheat — interactive guide/launcher for these tools"
)
ITEM_SEL=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)

# Only offer switching the login shell when it isn't already zsh. Defaults
# to unselected (even under --all): changing the login shell is system-wide
# and needs a re-login to take effect, so it should be opt-in, not implied
# by "install everything".
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
	ITEM_CATS+=(4)
	ITEM_IDS+=(switch-shell)
	ITEM_LABELS+=("Switch default shell to zsh (currently ${SHELL:-unknown})")
	ITEM_SEL+=(0)
fi

sel() { # sel <id> — succeeds if that item is selected
	local i
	for ((i = 0; i < ${#ITEM_IDS[@]}; i++)); do
		if [ "${ITEM_IDS[$i]}" = "$1" ]; then
			[ "${ITEM_SEL[$i]}" -eq 1 ]
			return
		fi
	done
	return 1
}

cat_items() { # indices of items in category $1
	local i out=""
	for ((i = 0; i < ${#ITEM_CATS[@]}; i++)); do
		if [ "${ITEM_CATS[$i]}" -eq "$1" ]; then out="$out $i"; fi
	done
	echo $out
}

cat_size() {
	local c=0 idx
	for idx in $(cat_items "$1"); do c=$((c + 1)); done
	echo "$c"
}

cat_item_at() { # item index at position $2 within category $1
	local n=0 idx
	for idx in $(cat_items "$1"); do
		if [ "$n" -eq "$2" ]; then
			echo "$idx"
			return
		fi
		n=$((n + 1))
	done
}

toggle_cat() { # select all items in category $1, or none if all were selected
	local idx all=1 newv
	for idx in $(cat_items "$1"); do
		if [ "${ITEM_SEL[$idx]}" -eq 0 ]; then all=0; fi
	done
	newv=1
	if [ "$all" -eq 1 ]; then newv=0; fi
	for idx in $(cat_items "$1"); do ITEM_SEL[$idx]=$newv; done
}

# ---------------------------------------------------------------------------
# Interactive menu (reads keys from /dev/tty so `curl | bash` stays interactive)
# ---------------------------------------------------------------------------
KEY=""
KEY_UP=$'\x1b[A' KEY_DOWN=$'\x1b[B' KEY_RIGHT=$'\x1b[C' KEY_LEFT=$'\x1b[D'

read_key() {
	local k="" rest=""
	IFS= read -rsn1 k </dev/tty || {
		KEY="q"
		return
	}
	if [ "$k" = $'\x1b' ]; then
		IFS= read -rsn2 -t 1 rest </dev/tty || true
		k="$k$rest"
	fi
	KEY="$k"
}

draw_top() { # $1 = cursor
	local i mark counts s t
	{
		printf '\033[H\033[2J'
		printf 'dotfiles installer — choose what to set up\n\n'
		for ((i = 0; i < ${#CAT_NAMES[@]}; i++)); do
			counts=$(cat_count "$i")
			s=${counts%% *} t=${counts##* }
			if [ "$s" -eq "$t" ]; then mark="x"; elif [ "$s" -eq 0 ]; then mark=" "; else mark="-"; fi
			if [ "$i" -eq "$1" ]; then printf ' > '; else printf '   '; fi
			printf '[%s] %s (%s/%s)\n' "$mark" "${CAT_NAMES[$i]}" "$s" "$t"
		done
		printf '\n   ↑/↓ move · space toggle · > drill down · enter install · q quit\n'
	} >/dev/tty
}

cat_count() { # "selected total" for category $1
	local idx s=0 t=0
	for idx in $(cat_items "$1"); do
		t=$((t + 1))
		if [ "${ITEM_SEL[$idx]}" -eq 1 ]; then s=$((s + 1)); fi
	done
	echo "$s $t"
}

draw_cat() { # $1 = category, $2 = cursor
	local idx n=0 mark
	{
		printf '\033[H\033[2J'
		printf '%s\n\n' "${CAT_NAMES[$1]}"
		for idx in $(cat_items "$1"); do
			if [ "${ITEM_SEL[$idx]}" -eq 1 ]; then mark="x"; else mark=" "; fi
			if [ "$n" -eq "$2" ]; then printf ' > '; else printf '   '; fi
			printf '[%s] %s\n' "$mark" "${ITEM_LABELS[$idx]}"
			n=$((n + 1))
		done
		printf '\n   ↑/↓ move · space toggle · < back\n'
	} >/dev/tty
}

run_menu() {
	local view=-1 cursor=0 rows ii
	trap 'printf "\033[?25h" > /dev/tty 2>/dev/null || true' EXIT
	printf '\033[?25l' >/dev/tty
	while :; do
		if [ "$view" -eq -1 ]; then
			rows=${#CAT_NAMES[@]}
			draw_top "$cursor"
		else
			rows=$(cat_size "$view")
			draw_cat "$view" "$cursor"
		fi
		read_key
		case "$KEY" in
		"$KEY_UP" | k)
			cursor=$((cursor - 1))
			if [ "$cursor" -lt 0 ]; then cursor=$((rows - 1)); fi
			;;
		"$KEY_DOWN" | j)
			cursor=$((cursor + 1))
			if [ "$cursor" -ge "$rows" ]; then cursor=0; fi
			;;
		' ')
			if [ "$view" -eq -1 ]; then
				toggle_cat "$cursor"
			else
				ii=$(cat_item_at "$view" "$cursor")
				if [ "${ITEM_SEL[$ii]}" -eq 1 ]; then ITEM_SEL[$ii]=0; else ITEM_SEL[$ii]=1; fi
			fi
			;;
		'>' | "$KEY_RIGHT")
			if [ "$view" -eq -1 ]; then
				view=$cursor
				cursor=0
			fi
			;;
		'<' | "$KEY_LEFT")
			if [ "$view" -ne -1 ]; then
				cursor=$view
				view=-1
			fi
			;;
		'')
			if [ "$view" -eq -1 ]; then
				break
			else
				cursor=$view
				view=-1
			fi
			;;
		q | Q)
			if [ "$view" -eq -1 ]; then
				printf '\033[?25h\n' >/dev/tty
				echo "Aborted — nothing installed."
				exit 0
			else
				cursor=$view
				view=-1
			fi
			;;
		esac
	done
	printf '\033[?25h' >/dev/tty
	printf '\033[H\033[2J' >/dev/tty
}

# ---------------------------------------------------------------------------
# Decide interactive vs everything
# ---------------------------------------------------------------------------
INTERACTIVE=1
if [ "${1:-}" = "--all" ] || [ "${DOTFILES_ALL:-}" = "1" ]; then
	INTERACTIVE=0
elif ! { : </dev/tty; } 2>/dev/null; then
	echo "==> No terminal available for the menu; installing everything."
	INTERACTIVE=0
fi

if [ "$INTERACTIVE" -eq 1 ]; then run_menu; fi

SELECTED=""
for ((i = 0; i < ${#ITEM_IDS[@]}; i++)); do
	if [ "${ITEM_SEL[$i]}" -eq 1 ]; then SELECTED="$SELECTED ${ITEM_IDS[$i]}"; fi
done
if [ -z "$SELECTED" ]; then
	echo "Nothing selected — exiting."
	exit 0
fi

echo "==> Using dotfiles at $DOTFILES_DIR ($OS)"
echo "==> Selected:$SELECTED"

if [ -n "${DOTFILES_DRY_RUN:-}" ]; then
	echo "==> Dry run — nothing was installed."
	exit 0
fi

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
ensure_brew() {
	if ! command -v brew &>/dev/null; then
		echo "==> Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [ -x /opt/homebrew/bin/brew ]; then
			eval "$(/opt/homebrew/bin/brew shellenv)"
		elif [ -x /usr/local/bin/brew ]; then
			eval "$(/usr/local/bin/brew shellenv)"
		fi
	fi
}

if [ "$OS" = "Darwin" ]; then
	formulas=""
	for id in tmux fzf tree micro yazi eza starship lazygit btop gdu pet; do
		sel "$id" && formulas="$formulas $id"
	done
	sel zsh-plugins && formulas="$formulas zsh-autosuggestions zsh-syntax-highlighting"

	if [ -n "$formulas" ] || sel nerd-font; then
		ensure_brew
		echo "==> Installing packages via Homebrew..."
		for f in $formulas; do
			brew list "$f" &>/dev/null || brew install "$f"
		done
		if sel nerd-font; then
			brew list --cask font-jetbrains-mono-nerd-font &>/dev/null ||
				brew install --cask font-jetbrains-mono-nerd-font
		fi
	fi

elif [ "$OS" = "Linux" ]; then
	apt_pkgs=""
	for id in tmux fzf tree micro; do
		sel "$id" && apt_pkgs="$apt_pkgs $id"
	done
	sel zshrc && apt_pkgs="$apt_pkgs zsh"
	sel zsh-plugins && apt_pkgs="$apt_pkgs zsh zsh-autosuggestions zsh-syntax-highlighting"
	sel switch-shell && apt_pkgs="$apt_pkgs zsh"
	sel tmux-plugins && apt_pkgs="$apt_pkgs git"
	if sel starship || sel eza || sel yazi || sel nerd-font || sel btop || sel gdu || sel lazygit || sel pet; then
		apt_pkgs="$apt_pkgs curl ca-certificates"
	fi
	if sel yazi || sel nerd-font; then apt_pkgs="$apt_pkgs unzip"; fi
	sel nerd-font && apt_pkgs="$apt_pkgs fontconfig"

	if [ -n "$apt_pkgs" ]; then
		echo "==> Installing packages via apt..."
		sudo apt-get update
		sudo apt-get install -y $apt_pkgs
	fi

	# Three different arch-naming conventions across ecosystems: Rust gnu
	# target triples (eza/yazi), Rust musl triples (btop), and Go-style
	# arch strings (gdu, lazygit — which oddly uses "x86_64" not "amd64").
	case "$(uname -m)" in
	aarch64 | arm64)
		RUST_TARGET="aarch64-unknown-linux-gnu"
		MUSL_TARGET="aarch64-unknown-linux-musl"
		GO_ARCH="arm64"
		LAZYGIT_ARCH="arm64"
		;;
	x86_64)
		RUST_TARGET="x86_64-unknown-linux-gnu"
		MUSL_TARGET="x86_64-unknown-linux-musl"
		GO_ARCH="amd64"
		LAZYGIT_ARCH="x86_64"
		;;
	*)
		RUST_TARGET=""
		MUSL_TARGET=""
		GO_ARCH=""
		LAZYGIT_ARCH=""
		;;
	esac

	if sel starship && ! command -v starship &>/dev/null; then
		echo "==> Installing starship (not in apt)..."
		curl -sS https://starship.rs/install.sh | sh -s -- --yes
	fi

	if sel eza && ! command -v eza &>/dev/null; then
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

	if sel yazi && ! command -v yazi &>/dev/null; then
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

	if sel btop && ! command -v btop &>/dev/null; then
		if [ -n "$MUSL_TARGET" ]; then
			echo "==> Installing btop (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/aristocratos/btop/releases/latest/download/btop-${MUSL_TARGET}.tar.gz" |
				tar -xz -C "$tmp"
			sudo install -m 755 "$tmp/btop/bin/btop" /usr/local/bin/btop
			rm -rf "$tmp"
		else
			echo "!! Skipping btop: unsupported architecture $(uname -m)"
		fi
	fi

	if sel gdu && ! command -v gdu &>/dev/null; then
		if [ -n "$GO_ARCH" ]; then
			echo "==> Installing gdu (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/dundee/gdu/releases/latest/download/gdu_linux_${GO_ARCH}.tgz" |
				tar -xz -C "$tmp"
			sudo install -m 755 "$tmp/gdu_linux_${GO_ARCH}" /usr/local/bin/gdu
			rm -rf "$tmp"
		else
			echo "!! Skipping gdu: unsupported architecture $(uname -m)"
		fi
	fi

	if sel lazygit && ! command -v lazygit &>/dev/null; then
		if [ -n "$LAZYGIT_ARCH" ]; then
			echo "==> Installing lazygit (not in apt)..."
			# lazygit's release filenames embed the version, so a fixed
			# .../latest/download/<name> URL doesn't work — look it up.
			lg_url="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
				grep -o "https://github.com/jesseduffield/lazygit/releases/download/[^\"]*linux_${LAZYGIT_ARCH}\.tar\.gz")"
			if [ -n "$lg_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$lg_url" | tar -xz -C "$tmp" lazygit
				sudo install -m 755 "$tmp/lazygit" /usr/local/bin/lazygit
				rm -rf "$tmp"
			else
				echo "!! Could not determine lazygit download URL, skipping"
			fi
		else
			echo "!! Skipping lazygit: unsupported architecture $(uname -m)"
		fi
	fi

	if sel pet && ! command -v pet &>/dev/null; then
		if [ -n "$GO_ARCH" ]; then
			echo "==> Installing pet (not in apt)..."
			# pet's release filenames embed the version too — look it up,
			# same as lazygit above. It ships .deb packages, so install
			# via dpkg instead of extracting a tarball manually.
			pet_url="$(curl -fsSL https://api.github.com/repos/knqyf263/pet/releases/latest |
				grep -o "https://github.com/knqyf263/pet/releases/download/[^\"]*linux_${GO_ARCH}\.deb")"
			if [ -n "$pet_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$pet_url" -o "$tmp/pet.deb"
				sudo dpkg -i "$tmp/pet.deb"
				rm -rf "$tmp"
			else
				echo "!! Could not determine pet download URL, skipping"
			fi
		else
			echo "!! Skipping pet: unsupported architecture $(uname -m)"
		fi
	fi

	if sel nerd-font; then
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
if sel tmux-config; then
	link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
	link "$DOTFILES_DIR/tmux/scripts" "$HOME/.config/tmux/scripts"
fi
sel yazi-config && link "$DOTFILES_DIR/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml"
sel inputrc && link "$DOTFILES_DIR/readline/inputrc" "$HOME/.inputrc"
sel eza-theme && link "$DOTFILES_DIR/eza/theme.yml" "$HOME/.config/eza/theme.yml"
sel cheat && link "$DOTFILES_DIR/cheat/cheat" "$HOME/.local/bin/cheat"

if sel btop-theme; then
	link "$DOTFILES_DIR/btop/catppuccin_mocha.theme" "$HOME/.config/btop/themes/catppuccin_mocha.theme"
	# btop.conf is a plain key=value file it regenerates with defaults for
	# anything missing, so it's safe to just ensure this one line is set
	# rather than symlinking (and clobbering) the whole file.
	btop_conf="$HOME/.config/btop/btop.conf"
	mkdir -p "$(dirname "$btop_conf")"
	touch "$btop_conf"
	if grep -q '^color_theme' "$btop_conf"; then
		sed -i.bak 's/^color_theme.*/color_theme = "catppuccin_mocha"/' "$btop_conf" && rm -f "$btop_conf.bak"
	else
		echo 'color_theme = "catppuccin_mocha"' >>"$btop_conf"
	fi
fi

# ---------------------------------------------------------------------------
# 3. zsh: source our snippet from ~/.zshrc without touching the rest of it
# ---------------------------------------------------------------------------
if sel zshrc; then
	ZSHRC="$HOME/.zshrc"
	SOURCE_LINE="[ -f \"$DOTFILES_DIR/zsh/zshrc.dotfiles\" ] && source \"$DOTFILES_DIR/zsh/zshrc.dotfiles\""
	touch "$ZSHRC"
	if grep -qF "$SOURCE_LINE" "$ZSHRC"; then
		echo "==> $ZSHRC already sources dotfiles from the current location, skipping"
	else
		# A line mentioning zshrc.dotfiles but not matching SOURCE_LINE means
		# the repo moved (e.g. an earlier run cloned to a different path) —
		# drop the stale line instead of leaving it dangling alongside a new one.
		if grep -qF "zshrc.dotfiles" "$ZSHRC"; then
			echo "==> Removing stale dotfiles source line from $ZSHRC..."
			tmp="$(mktemp)"
			grep -vF "zshrc.dotfiles" "$ZSHRC" | grep -vF "# Load shared dotfiles settings" >"$tmp"
			mv "$tmp" "$ZSHRC"
		fi
		{
			echo ""
			echo "# Load shared dotfiles settings"
			echo "$SOURCE_LINE"
		} >>"$ZSHRC"
		echo "==> Added dotfiles source line to $ZSHRC"
	fi
fi

# ---------------------------------------------------------------------------
# 4. git
# ---------------------------------------------------------------------------
if sel git-editor; then
	echo "==> Setting git core.editor..."
	git config --global core.editor "micro"
fi

# ---------------------------------------------------------------------------
# 5. tmux plugins (TPM)
# ---------------------------------------------------------------------------
if sel tmux-plugins; then
	TPM_DIR="$HOME/.config/tmux/plugins/tpm"
	if [ ! -d "$TPM_DIR" ]; then
		echo "==> Installing TPM..."
		git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
	fi

	echo "==> Installing tmux plugins..."
	TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins/" "$TPM_DIR/bin/install_plugins"
fi

# ---------------------------------------------------------------------------
# 6. Switch default shell to zsh (only offered/selectable if not already zsh)
# ---------------------------------------------------------------------------
SHELL_SWITCHED=0
if sel switch-shell; then
	zsh_path="$(command -v zsh || true)"
	if [ -z "$zsh_path" ]; then
		echo "!! zsh not found on PATH — skipping shell switch"
	else
		if [ -f /etc/shells ] && ! grep -qxF "$zsh_path" /etc/shells; then
			echo "==> Adding $zsh_path to /etc/shells..."
			echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
		fi
		echo "==> Switching default shell to zsh (may prompt for your password)..."
		if chsh -s "$zsh_path"; then
			SHELL_SWITCHED=1
		else
			echo "!! Could not switch automatically. Run manually: chsh -s $zsh_path"
		fi
	fi
fi

cat <<'EOF'

==> Done!

Next steps:
  - Open a new terminal (or run: source ~/.zshrc)
  - Run "cheat" — an interactive, tabbed guide to everything installed
EOF
if [ "$SHELL_SWITCHED" -eq 1 ]; then
	echo "  - Default shell is now zsh — log out and back in for it to take effect"
elif [ "$(basename "${SHELL:-}")" != "zsh" ]; then
	echo "  - Your login shell isn't zsh, so the zsh settings above won't take"
	echo "    effect until you switch: chsh -s \"\$(command -v zsh)\""
fi
cat <<'EOF'
  - Set your terminal's font to "JetBrainsMono Nerd Font" (needed for icons
    in the tmux status bar and prompt)
  - Start tmux and try: ` Space   (prefix + space opens the keybinding menu)
EOF
