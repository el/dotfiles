# dotfiles

Personal terminal setup: tmux, yazi, zsh, and git config, with a single
install script to bootstrap a new machine (macOS or Linux).

## Install on a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/el/dotfiles/master/bootstrap.sh | bash
```

Pasting the same command again later is safe: it updates the existing clone
at `~/dotfiles` (`git pull`) and re-runs the installer.

The installer opens an interactive picker (same look and feel as the
`cheat` tool it installs):

```
  dotfiles installer — choose what to set up

   Terminal & Prompt   File Tools   Git & Monitoring   Tmux   Zsh   Other Configs

   5/5 selected in this tab · 22/22 total
 > [x] tmux — terminal multiplexer
   [x] starship — shell prompt
   [x] JetBrainsMono Nerd Font
   [x] pet — command snippet manager (Ctrl-S to search)
   [x] cheat — interactive guide/launcher for these tools

  ─ info ──────────────────────────────────────────
  installs via Homebrew · already installed

  ←/→ tabs · ↑/↓ move · space toggle · a all/none · enter install · q quit
```

`←/→` switches category tabs, `space` toggles the highlighted item, `a`
toggles everything in the current tab, `enter` installs the selection. The
info pane shows how the highlighted item installs on this OS (Homebrew /
apt / upstream release / symlink destination) and whether it's already
present. To skip the menu and install everything (also what happens when no
terminal is attached):

```sh
curl -fsSL https://raw.githubusercontent.com/el/dotfiles/master/bootstrap.sh | bash -s -- --all
```

Manual equivalent:

```sh
git clone https://github.com/el/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh          # interactive menu
./install.sh --all    # everything, no menu
```

The installer is safe to re-run (every step is idempotent, and any real
config file already in place is backed up with a `.bak.<timestamp>` suffix
before being replaced by a symlink). It detects the OS:

- **macOS**: packages via [Homebrew](https://brew.sh) (installed if missing)
- **Linux**: `tmux`, `fzf`, `tree`, `micro`, `zsh`, and the zsh plugins via
  `apt`; `starship`, `eza`, `yazi`, `btop`, `gdu`, `lazygit`, and the Nerd
  Font aren't reliably in apt repos (or drift across distro versions), so
  those are fetched from upstream instead (official installer for starship,
  prebuilt release binaries for the rest, font zip + `fc-cache`)

What it sets up (each individually selectable in the menu):

- **Terminal & Prompt**: `tmux`, `starship`, `pet`, `cheat` (see below), the
  JetBrains Mono Nerd Font
- **File Tools**: `fzf`, `tree`, `micro`, `yazi`, `eza`
- **Git & Monitoring**: `lazygit`, `btop`, `gdu`
- Symlinks: `tmux/tmux.conf` + `tmux/scripts/` -> `~/.config/tmux/`,
  `yazi/keymap.toml` -> `~/.config/yazi/`, `readline/inputrc` ->
  `~/.inputrc`, `eza/theme.yml` -> `~/.config/eza/`,
  `btop/catppuccin_mocha.theme` -> `~/.config/btop/themes/` (and sets
  `color_theme` in `btop.conf`)
- A line in `~/.zshrc` that sources `zsh/zshrc.dotfiles` (your existing
  `~/.zshrc` is otherwise untouched)
- `git config --global core.editor micro`
- [TPM](https://github.com/tmux-plugins/tpm) and all tmux plugins

Note: on macOS, Homebrew installs `gdu`'s binary as `gdu-go` (it conflicts
with coreutils' own `gdu`). `zshrc.dotfiles` aliases `gdu` to `gdu-go`
automatically when that's the case, so the command is just `gdu` either way.

After it finishes: open a new terminal (or `source ~/.zshrc`), set your
terminal's font to **JetBrainsMono Nerd Font** (needed for the status bar
icons — e.g. in iTerm2: Preferences > Profiles > Text), then start tmux.

Everything here assumes **zsh** as your login shell (macOS defaults to it;
most Linux distros default to bash). If `echo $SHELL` doesn't say `zsh`,
run `chsh -s "$(command -v zsh)"` and re-login, otherwise `zsh/zshrc.dotfiles`
never gets sourced.

## What's in here

| Path | Purpose |
|---|---|
| `tmux/tmux.conf` | Full tmux config |
| `tmux/scripts/` | Helper scripts tmux/yazi shell out to |
| `yazi/keymap.toml` | Custom yazi keybindings |
| `zsh/zshrc.dotfiles` | `EDITOR`/`VISUAL`, prompt + zsh plugins — sourced from `~/.zshrc` |
| `zsh/starship.toml` | [Starship](https://starship.rs) prompt config (Catppuccin mocha, matching tmux) |
| `readline/inputrc` | Arrow keys do prefix-based history search |
| `eza/theme.yml` | [Catppuccin mocha (mauve)](https://github.com/catppuccin/eza) theme for `ls`/`ll`/`la`/`lt` ([eza](https://eza.rocks)) |
| `btop/catppuccin_mocha.theme` | [Catppuccin mocha](https://github.com/catppuccin/btop) theme for [btop](https://github.com/aristocratos/btop) |
| `cheat/cheat` | The `cheat` command — interactive guide/launcher for all these tools (symlinked to `~/.local/bin/cheat`) |
| `bootstrap.sh` | `curl \| bash` entry point — clones/updates the repo, then runs `install.sh` |
| `install.sh` | Interactive installer (macOS via Homebrew, Linux via apt + upstream installers) |

## Shell aliases

| Alias | Runs |
|---|---|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -l --icons --group-directories-first --git --header` |
| `la` | `eza -la --icons --group-directories-first --git --header` |
| `lt` | `eza --tree --icons --group-directories-first --level=2` |

## Other CLI apps

Run **`cheat`** for an interactive version of this list: tabs per category
(←/→ to switch), a table of the tools that are actually installed (↑/↓ to
select), tips for the highlighted tool, and enter to launch it — you come
back to the menu when the tool exits.

| Command | What |
|---|---|
| [`lazygit`](https://github.com/jesseduffield/lazygit) | Git TUI — stage, commit, branch, rebase; mouse-clickable panels |
| [`btop`](https://github.com/aristocratos/btop) | System monitor (CPU/mem/disk/net/proc), Catppuccin themed, mouse support |
| `gdu` | Disk usage analyzer with mouse support (aliased from `gdu-go` on macOS) |
| [`pet`](https://github.com/knqyf263/pet) | Command snippet manager — save/search reusable commands. `pet new` to save one, or press **Ctrl-S** anywhere in the shell to search (unrelated to tmux's `` ` `` `Ctrl-s`, which needs the prefix key first) |

## tmux cheat sheet

Prefix is **`` ` ``** (backtick) instead of the default `Ctrl-b`. Tap it
twice to send a literal backtick to the shell.

| Key | Action |
|---|---|
| `` ` `` `\|` / `` ` `` `-` | Split vertically / horizontally (keeps cwd) |
| `` ` `` `c` | New window (keeps cwd) |
| `` ` `` `h/j/k/l` | Move between panes |
| `` ` `` `H/J/K/L` | Resize panes |
| `` ` `` `Tab` | Jump to last window |
| `` ` `` `r` | Reload config |
| `` ` `` `Enter` then `v`/`y` | Copy mode: select / copy (to macOS clipboard) |
| `` ` `` `F` | Fuzzy-find sessions/windows/panes ([tmux-fzf](https://github.com/sainnhe/tmux-fzf)) |
| `` ` `` `e` | Hint-based mouse-free copy of paths/URLs ([extrakto](https://github.com/laktak/extrakto)) |
| `` ` `` `Space` | Keybinding cheat-sheet / command palette ([tmux-which-key](https://github.com/alexwforsythe/tmux-which-key)) |
| `` ` `` `\` | General popup menu ([tmux-menus](https://github.com/jaclu/tmux-menus)) |
| `` ` `` `o` | Toggle a [yazi](https://yazi-rs.github.io/) file-manager pane on the left |
| `` ` `` `Ctrl-s` / `` ` `` `Ctrl-r` | Manually save / restore session layout ([tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect); auto-saves every 15 min via [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)) |

Inside the yazi sidebar pane:

| Key | Action |
|---|---|
| `Ctrl-o` | Open the hovered file with `$EDITOR` in the other pane |
| `Ctrl-g` | `cd` the other pane to yazi's current directory |

Theme is [Catppuccin](https://github.com/catppuccin/tmux) (mocha flavor).
