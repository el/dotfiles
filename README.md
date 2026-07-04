# dotfiles

Personal terminal setup: tmux, yazi, zsh, and git config, with a single
install script to bootstrap a new machine (macOS or Linux).

## Install on a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/el/dotfiles/master/bootstrap.sh | bash
```

Pasting the same command again later is safe: it updates the existing clone
at `~/Developer/dotfiles` (`git pull`) and re-runs the installer.

The installer opens an interactive picker:

```
dotfiles installer — choose what to set up

 > [x] CLI Apps (8/8)
   [x] Tmux (2/2)
   [x] Zsh (2/2)
   [x] Other Configs (4/4)

   ↑/↓ move · space toggle · > drill down · enter install · q quit
```

`space` toggles a whole category, `>` drills into it to select/unselect
individual items, `<` goes back, `enter` installs the selection. To skip the
menu and install everything (also what happens when no terminal is attached):

```sh
curl -fsSL https://raw.githubusercontent.com/el/dotfiles/master/bootstrap.sh | bash -s -- --all
```

Manual equivalent:

```sh
git clone https://github.com/el/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
./install.sh          # interactive menu
./install.sh --all    # everything, no menu
```

The installer is safe to re-run (every step is idempotent, and any real
config file already in place is backed up with a `.bak.<timestamp>` suffix
before being replaced by a symlink). It detects the OS:

- **macOS**: packages via [Homebrew](https://brew.sh) (installed if missing)
- **Linux**: `tmux`, `fzf`, `tree`, `micro`, `zsh`, and the zsh plugins via
  `apt`; `starship`, `eza`, `yazi`, and the Nerd Font aren't reliably in apt
  repos, so those are fetched from upstream (official installer for
  starship, prebuilt release binaries for eza/yazi, font zip + `fc-cache`)

What it sets up (each individually selectable in the menu):

- CLI apps: `tmux`, `fzf`, `tree`, `micro`, `yazi`, `eza`, `starship`, and
  the JetBrains Mono Nerd Font
- Symlinks: `tmux/tmux.conf` + `tmux/scripts/` -> `~/.config/tmux/`,
  `yazi/keymap.toml` -> `~/.config/yazi/`, `readline/inputrc` ->
  `~/.inputrc`, `eza/theme.yml` -> `~/.config/eza/`
- A line in `~/.zshrc` that sources `zsh/zshrc.dotfiles` (your existing
  `~/.zshrc` is otherwise untouched)
- `git config --global core.editor micro`
- [TPM](https://github.com/tmux-plugins/tpm) and all tmux plugins

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
| `bootstrap.sh` | `curl \| bash` entry point — clones/updates the repo, then runs `install.sh` |
| `install.sh` | Interactive installer (macOS via Homebrew, Linux via apt + upstream installers) |

## Shell aliases

| Alias | Runs |
|---|---|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -l --icons --group-directories-first --git --header` |
| `la` | `eza -la --icons --group-directories-first --git --header` |
| `lt` | `eza --tree --icons --group-directories-first --level=2` |

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
