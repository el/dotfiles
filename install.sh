#!/usr/bin/env bash
# Bootstraps terminal settings (tmux, yazi, zsh, git) on a new machine.
#
# Usage:
#   ./install.sh          interactive menu to pick what to install
#   ./install.sh --all    install the default selection, no menu
#                         (skips DEFAULT_OFF items and switch-shell)
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
# lazygit, fastfetch, serpl, and the Nerd Font aren't reliably in apt repos
# (or drift across distro versions), so those come from upstream
# releases/installers instead. toolong has no native package anywhere, so
# it's installed via pipx on both OSes.
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

ITEM_CATS=(0 1 1 1 1 1 0 0 2 2 2 3 3 4 4 5 5 5 5 5 0 0 0 1 1 1 1 2 2 0 0 2 1 1 0 0)
ITEM_IDS=(tmux fzf tree micro yazi eza starship nerd-font
	lazygit btop gdu
	tmux-config tmux-plugins zshrc zsh-plugins
	yazi-config eza-theme btop-theme inputrc git-editor
	pet cheat
	tealdeer bat television jless glow gping bandwhich
	zoxide atuin
	fastfetch toolong serpl weather navi)
ITEM_LABELS=(
	"tmux — terminal multiplexer"
	"fzf — fuzzy finder (powers the tmux-fzf and extrakto tmux plugins)"
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
	"tealdeer — tldr cheatsheet pages (command: tldr)"
	"bat — cat with syntax highlighting"
	"television — general fuzzy finder TUI (command: tv)"
	"jless — interactive JSON viewer"
	"glow — markdown reader"
	"gping — ping with a live graph"
	"bandwhich — per-process bandwidth monitor"
	"zoxide — smarter cd that learns your habits"
	"atuin — searchable shell history (SQLite-backed, replaces Ctrl-R)"
	"fastfetch — system info display (like neofetch, much faster)"
	"toolong — terminal log viewer/tailer (command: tl)"
	"serpl — interactive terminal search & replace"
	"weather — forecast via wttr.in (command: weather)"
	"navi — interactive cheatsheet tool, fills in and runs commands"
)
ITEM_SEL=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)

# These start unselected (opt-in via the menu; --all also skips them).
DEFAULT_OFF="fzf tree lazygit tealdeer glow zoxide atuin navi"
for _off_id in $DEFAULT_OFF; do
	for ((i = 0; i < ${#ITEM_IDS[@]}; i++)); do
		if [ "${ITEM_IDS[$i]}" = "$_off_id" ]; then ITEM_SEL[$i]=0; fi
	done
done

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

any_sel() { # succeeds if any of the given ids is selected
	local id
	for id in "$@"; do
		if sel "$id"; then return 0; fi
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

cat_count() { # "selected total" for category $1
	local idx s=0 t=0
	for idx in $(cat_items "$1"); do
		t=$((t + 1))
		if [ "${ITEM_SEL[$idx]}" -eq 1 ]; then s=$((s + 1)); fi
	done
	echo "$s $t"
}

total_count() { # "selected total" across everything
	local i s=0
	for ((i = 0; i < ${#ITEM_SEL[@]}; i++)); do
		if [ "${ITEM_SEL[$i]}" -eq 1 ]; then s=$((s + 1)); fi
	done
	echo "$s ${#ITEM_SEL[@]}"
}

item_info() { # $1 = item id → one-line note for the info pane
	local id="$1" method="" installed=""
	case "$id" in
	cheat)
		echo "symlink → ~/.local/bin/cheat"
		return
		;;
	weather)
		echo "symlink → ~/.local/bin/weather"
		return
		;;
	tmux-config)
		echo "symlinks → ~/.config/tmux/tmux.conf + scripts/"
		return
		;;
	tmux-plugins)
		echo "TPM clone + plugin install → ~/.config/tmux/plugins/"
		return
		;;
	zshrc)
		echo "adds one source line to ~/.zshrc"
		return
		;;
	yazi-config)
		echo "symlink → ~/.config/yazi/keymap.toml"
		return
		;;
	eza-theme)
		echo "symlink → ~/.config/eza/theme.yml"
		return
		;;
	btop-theme)
		echo "symlink + color_theme line in ~/.config/btop/btop.conf"
		return
		;;
	inputrc)
		echo "symlink → ~/.inputrc"
		return
		;;
	git-editor)
		echo "git config --global core.editor micro"
		return
		;;
	switch-shell)
		echo "runs chsh -s zsh (asks for your password; needs re-login)"
		return
		;;
	esac
	# Everything else is a package.
	if [ "$OS" = "Darwin" ]; then
		case "$id" in
		nerd-font) method="Homebrew cask" ;;
		toolong) method="pipx (Python package)" ;;
		*) method="Homebrew" ;;
		esac
	else
		case "$id" in
		tmux | fzf | tree | micro | zsh-plugins) method="apt" ;;
		nerd-font) method="upstream download + fc-cache" ;;
		starship) method="official install script" ;;
		pet | television | glow) method="upstream .deb package" ;;
		jless) method="upstream release (Linux x86_64 only)" ;;
		fastfetch) method="upstream .deb package" ;;
		toolong) method="pipx (Python package)" ;;
		*) method="upstream release binary" ;;
		esac
	fi
	# Some packages install a binary named differently from the item id.
	local bin="$id"
	case "$id" in
	television) bin="tv" ;;
	tealdeer) bin="tldr" ;;
	toolong) bin="tl" ;;
	esac
	case "$id" in
	nerd-font | zsh-plugins) ;;
	gdu)
		if command -v gdu >/dev/null 2>&1 || command -v gdu-go >/dev/null 2>&1; then
			installed=" · already installed"
		fi
		;;
	*)
		if command -v "$bin" >/dev/null 2>&1; then installed=" · already installed"; fi
		;;
	esac
	echo "installs via ${method}${installed}"
}

draw_menu() { # $1 = active tab, $2 = cursor row
	local c i n mark counts s t info
	{
		printf '\033[H\033[2J'
		printf '  \033[1mdotfiles installer\033[0m \033[2m— choose what to set up\033[0m\n\n  '
		for ((c = 0; c < ${#CAT_NAMES[@]}; c++)); do
			if [ "$c" -eq "$1" ]; then
				printf '\033[7;1m %s \033[0m ' "${CAT_NAMES[$c]}"
			else
				printf '\033[2m %s \033[0m ' "${CAT_NAMES[$c]}"
			fi
		done
		counts=$(cat_count "$1")
		s=${counts%% *} t=${counts##* }
		printf '\n\n   \033[2m%s/%s selected in this tab' "$s" "$t"
		counts=$(total_count)
		s=${counts%% *} t=${counts##* }
		printf ' · %s/%s total\033[0m\n' "$s" "$t"
		n=0
		for i in $(cat_items "$1"); do
			if [ "${ITEM_SEL[$i]}" -eq 1 ]; then mark="x"; else mark=" "; fi
			if [ "$n" -eq "$2" ]; then
				printf ' \033[1;36m> [%s] %s\033[0m\n' "$mark" "${ITEM_LABELS[$i]}"
			else
				printf '   [%s] %s\n' "$mark" "${ITEM_LABELS[$i]}"
			fi
			n=$((n + 1))
		done
		i=$(cat_item_at "$1" "$2")
		info=$(item_info "${ITEM_IDS[$i]}")
		printf '\n  \033[2m─ info ──────────────────────────────────────────\033[0m\n'
		printf '  \033[2m%s\033[0m\n' "$info"
		printf '\n  \033[2m←/→ tabs · ↑/↓ move · space toggle · a all/none · enter install · q quit\033[0m\n'
	} >/dev/tty
}

run_menu() {
	local tab=0 cursor=0 rows ii
	trap 'printf "\033[?25h" > /dev/tty 2>/dev/null || true' EXIT
	printf '\033[?25l' >/dev/tty
	while :; do
		rows=$(cat_size "$tab")
		if [ "$cursor" -ge "$rows" ]; then cursor=$((rows - 1)); fi
		draw_menu "$tab" "$cursor"
		read_key
		case "$KEY" in
		"$KEY_LEFT" | h | '<')
			tab=$((tab - 1))
			if [ "$tab" -lt 0 ]; then tab=$((${#CAT_NAMES[@]} - 1)); fi
			cursor=0
			;;
		"$KEY_RIGHT" | l | '>')
			tab=$((tab + 1))
			if [ "$tab" -ge ${#CAT_NAMES[@]} ]; then tab=0; fi
			cursor=0
			;;
		"$KEY_UP" | k)
			cursor=$((cursor - 1))
			if [ "$cursor" -lt 0 ]; then cursor=$((rows - 1)); fi
			;;
		"$KEY_DOWN" | j)
			cursor=$((cursor + 1))
			if [ "$cursor" -ge "$rows" ]; then cursor=0; fi
			;;
		' ')
			ii=$(cat_item_at "$tab" "$cursor")
			if [ "${ITEM_SEL[$ii]}" -eq 1 ]; then ITEM_SEL[$ii]=0; else ITEM_SEL[$ii]=1; fi
			;;
		a | A)
			toggle_cat "$tab"
			;;
		'')
			break
			;;
		q | Q)
			printf '\033[?25h\n' >/dev/tty
			echo "Aborted — nothing installed."
			exit 0
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
	for id in tmux fzf tree micro yazi eza starship lazygit btop gdu pet \
		bat television tealdeer jless gping bandwhich glow zoxide atuin \
		fastfetch serpl navi; do
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

	# toolong has no Homebrew formula (it's a Textualize Python TUI) —
	# install it via pipx instead, same as upstream recommends.
	if sel toolong && ! command -v tl &>/dev/null; then
		echo "==> Installing toolong (pipx)..."
		brew list pipx &>/dev/null || brew install pipx
		pipx install toolong
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
	sel toolong && apt_pkgs="$apt_pkgs pipx"
	if any_sel starship eza yazi nerd-font btop gdu lazygit pet \
		bat television tealdeer jless gping bandwhich glow zoxide atuin \
		fastfetch serpl weather navi; then
		apt_pkgs="$apt_pkgs curl ca-certificates"
	fi
	if any_sel yazi nerd-font jless; then apt_pkgs="$apt_pkgs unzip"; fi
	sel nerd-font && apt_pkgs="$apt_pkgs fontconfig"

	if [ -n "$apt_pkgs" ]; then
		echo "==> Installing packages via apt..."
		sudo apt-get update
		sudo apt-get install -y $apt_pkgs
	fi

	# Different arch-naming conventions across ecosystems: Rust gnu target
	# triples (eza/yazi/bat/television), Rust musl triples (btop/bandwhich/
	# tealdeer), Go-style arch strings (gdu uses "amd64"), plain arm64/x86_64
	# (lazygit, gping, glow, serpl), fastfetch's own aarch64/amd64 pair, and
	# navi (only ships an aarch64 gnu build and an x86_64 musl build).
	case "$(uname -m)" in
	aarch64 | arm64)
		RUST_TARGET="aarch64-unknown-linux-gnu"
		MUSL_TARGET="aarch64-unknown-linux-musl"
		GO_ARCH="arm64"
		BIN_ARCH="arm64"
		FASTFETCH_ARCH="aarch64"
		NAVI_TARGET="aarch64-unknown-linux-gnu"
		;;
	x86_64)
		RUST_TARGET="x86_64-unknown-linux-gnu"
		MUSL_TARGET="x86_64-unknown-linux-musl"
		GO_ARCH="amd64"
		BIN_ARCH="x86_64"
		FASTFETCH_ARCH="amd64"
		NAVI_TARGET="x86_64-unknown-linux-musl"
		;;
	*)
		RUST_TARGET=""
		MUSL_TARGET=""
		GO_ARCH=""
		BIN_ARCH=""
		FASTFETCH_ARCH=""
		NAVI_TARGET=""
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
		if [ -n "$BIN_ARCH" ]; then
			echo "==> Installing lazygit (not in apt)..."
			# lazygit's release filenames embed the version, so a fixed
			# .../latest/download/<name> URL doesn't work — look it up.
			lg_url="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
				grep -o "https://github.com/jesseduffield/lazygit/releases/download/[^\"]*linux_${BIN_ARCH}\.tar\.gz")"
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

	if sel bat && ! command -v bat &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			# apt has bat, but Debian installs the binary as "batcat" —
			# upstream keeps the real name.
			echo "==> Installing bat (apt names it batcat)..."
			bat_url="$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest |
				grep -o "https://github.com/sharkdp/bat/releases/download/[^\"]*-${RUST_TARGET}\.tar\.gz" | head -1)"
			if [ -n "$bat_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$bat_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name bat | head -1)" /usr/local/bin/bat
				rm -rf "$tmp"
			else
				echo "!! Could not determine bat download URL, skipping"
			fi
		else
			echo "!! Skipping bat: unsupported architecture $(uname -m)"
		fi
	fi

	if sel television && ! command -v tv &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			echo "==> Installing television (not in apt)..."
			tv_url="$(curl -fsSL https://api.github.com/repos/alexpasmantier/television/releases/latest |
				grep -o "https://github.com/alexpasmantier/television/releases/download/[^\"]*-${RUST_TARGET}\.deb" | head -1)"
			if [ -n "$tv_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$tv_url" -o "$tmp/tv.deb"
				sudo dpkg -i "$tmp/tv.deb"
				rm -rf "$tmp"
			else
				echo "!! Could not determine television download URL, skipping"
			fi
		else
			echo "!! Skipping television: unsupported architecture $(uname -m)"
		fi
	fi

	if sel tealdeer && ! command -v tldr &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			echo "==> Installing tealdeer (not in apt)..."
			# Ships bare static binaries with fixed names, e.g.
			# tealdeer-linux-aarch64-musl
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${RUST_TARGET%%-*}-musl" -o "$tmp/tldr"
			sudo install -m 755 "$tmp/tldr" /usr/local/bin/tldr
			rm -rf "$tmp"
		else
			echo "!! Skipping tealdeer: unsupported architecture $(uname -m)"
		fi
	fi

	if sel jless && ! command -v jless &>/dev/null; then
		if [ "$(uname -m)" = "x86_64" ]; then
			echo "==> Installing jless (not in apt)..."
			jl_url="$(curl -fsSL https://api.github.com/repos/PaulJuliusMartinez/jless/releases/latest |
				grep -o "https://github.com/PaulJuliusMartinez/jless/releases/download/[^\"]*x86_64-unknown-linux-gnu\.zip" | head -1)"
			if [ -n "$jl_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$jl_url" -o "$tmp/jless.zip"
				unzip -q "$tmp/jless.zip" -d "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name jless | head -1)" /usr/local/bin/jless
				rm -rf "$tmp"
			else
				echo "!! Could not determine jless download URL, skipping"
			fi
		else
			echo "!! Skipping jless: upstream ships no Linux $(uname -m) build"
		fi
	fi

	if sel glow && ! command -v glow &>/dev/null; then
		if [ -n "$BIN_ARCH" ]; then
			echo "==> Installing glow (not in apt)..."
			glow_url="$(curl -fsSL https://api.github.com/repos/charmbracelet/glow/releases/latest |
				grep -o "https://github.com/charmbracelet/glow/releases/download/[^\"]*_Linux_${BIN_ARCH}\.tar\.gz" | head -1)"
			if [ -n "$glow_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$glow_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name glow | head -1)" /usr/local/bin/glow
				rm -rf "$tmp"
			else
				echo "!! Could not determine glow download URL, skipping"
			fi
		else
			echo "!! Skipping glow: unsupported architecture $(uname -m)"
		fi
	fi

	if sel gping && ! command -v gping &>/dev/null; then
		if [ -n "$BIN_ARCH" ]; then
			echo "==> Installing gping (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/orf/gping/releases/latest/download/gping-Linux-musl-${BIN_ARCH}.tar.gz" |
				tar -xz -C "$tmp"
			sudo install -m 755 "$(find "$tmp" -type f -name gping | head -1)" /usr/local/bin/gping
			rm -rf "$tmp"
		else
			echo "!! Skipping gping: unsupported architecture $(uname -m)"
		fi
	fi

	if sel bandwhich && ! command -v bandwhich &>/dev/null; then
		if [ -n "$MUSL_TARGET" ]; then
			echo "==> Installing bandwhich (not in apt)..."
			bw_url="$(curl -fsSL https://api.github.com/repos/imsnif/bandwhich/releases/latest |
				grep -o "https://github.com/imsnif/bandwhich/releases/download/[^\"]*-${MUSL_TARGET}\.tar\.gz" | head -1)"
			if [ -n "$bw_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$bw_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name bandwhich | head -1)" /usr/local/bin/bandwhich
				rm -rf "$tmp"
			else
				echo "!! Could not determine bandwhich download URL, skipping"
			fi
		else
			echo "!! Skipping bandwhich: unsupported architecture $(uname -m)"
		fi
	fi

	if sel zoxide && ! command -v zoxide &>/dev/null; then
		if [ -n "$MUSL_TARGET" ]; then
			echo "==> Installing zoxide (not in apt)..."
			# zoxide's release filenames embed the version, same as
			# lazygit/pet above — look it up rather than guessing.
			zx_url="$(curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest |
				grep -o "https://github.com/ajeetdsouza/zoxide/releases/download/[^\"]*${MUSL_TARGET}\.tar\.gz")"
			if [ -n "$zx_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$zx_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name zoxide | head -1)" /usr/local/bin/zoxide
				rm -rf "$tmp"
			else
				echo "!! Could not determine zoxide download URL, skipping"
			fi
		else
			echo "!! Skipping zoxide: unsupported architecture $(uname -m)"
		fi
	fi

	if sel atuin && ! command -v atuin &>/dev/null; then
		if [ -n "$RUST_TARGET" ]; then
			echo "==> Installing atuin (not in apt)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/atuinsh/atuin/releases/latest/download/atuin-${RUST_TARGET}.tar.gz" |
				tar -xz -C "$tmp"
			sudo install -m 755 "$(find "$tmp" -type f -name atuin | head -1)" /usr/local/bin/atuin
			rm -rf "$tmp"
		else
			echo "!! Skipping atuin: unsupported architecture $(uname -m)"
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

	if sel fastfetch && ! command -v fastfetch &>/dev/null; then
		if [ -n "$FASTFETCH_ARCH" ]; then
			echo "==> Installing fastfetch (not reliably in apt across distros)..."
			tmp="$(mktemp -d)"
			curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${FASTFETCH_ARCH}.deb" -o "$tmp/fastfetch.deb"
			sudo dpkg -i "$tmp/fastfetch.deb"
			rm -rf "$tmp"
		else
			echo "!! Skipping fastfetch: unsupported architecture $(uname -m)"
		fi
	fi

	if sel serpl && ! command -v serpl &>/dev/null; then
		if [ -n "$BIN_ARCH" ]; then
			echo "==> Installing serpl (not in apt)..."
			# serpl's release filenames embed the version, same as lazygit/pet
			# above — look it up rather than guessing.
			serpl_url="$(curl -fsSL https://api.github.com/repos/yassinebridi/serpl/releases/latest |
				grep -o "https://github.com/yassinebridi/serpl/releases/download/[^\"]*-linux-${BIN_ARCH}\.tar\.gz")"
			if [ -n "$serpl_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$serpl_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name serpl | head -1)" /usr/local/bin/serpl
				rm -rf "$tmp"
			else
				echo "!! Could not determine serpl download URL, skipping"
			fi
		else
			echo "!! Skipping serpl: unsupported architecture $(uname -m)"
		fi
	fi

	# toolong has no native Linux package — install via pipx (apt package
	# added to apt_pkgs above), same as upstream recommends.
	if sel toolong && ! command -v tl &>/dev/null; then
		echo "==> Installing toolong (pipx)..."
		pipx install toolong
	fi

	if sel navi && ! command -v navi &>/dev/null; then
		if [ -n "$NAVI_TARGET" ]; then
			echo "==> Installing navi (not in apt)..."
			# navi's release filenames embed the version, same as lazygit/pet
			# above — look it up rather than guessing.
			navi_url="$(curl -fsSL https://api.github.com/repos/denisidoro/navi/releases/latest |
				grep -o "https://github.com/denisidoro/navi/releases/download/[^\"]*-${NAVI_TARGET}\.tar\.gz")"
			if [ -n "$navi_url" ]; then
				tmp="$(mktemp -d)"
				curl -fsSL "$navi_url" | tar -xz -C "$tmp"
				sudo install -m 755 "$(find "$tmp" -type f -name navi | head -1)" /usr/local/bin/navi
				rm -rf "$tmp"
			else
				echo "!! Could not determine navi download URL, skipping"
			fi
		else
			echo "!! Skipping navi: unsupported architecture $(uname -m)"
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

# tealdeer errors on first use until its page cache exists — seed it now
if sel tealdeer && command -v tldr &>/dev/null; then
	echo "==> Seeding tldr page cache..."
	tldr --update >/dev/null 2>&1 || true
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
sel weather && link "$DOTFILES_DIR/weather/weather" "$HOME/.local/bin/weather"

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
