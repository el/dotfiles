# dotfiles

Personal terminal setup: tmux, yazi, zsh, and git config, with a single
install script to bootstrap a new machine (macOS or Linux).

## Install on a new machine

```sh
git clone https://github.com/el/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
./install.sh
```

The script is safe to re-run and detects the OS:

- **macOS**: installs [Homebrew](https://brew.sh) if missing, then everything
  from [`Brewfile`](Brewfile): `tmux`, `fzf`, `tree`, `yazi`, `micro`,
  `starship`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `eza`, and
  the JetBrains Mono Nerd Font
- **Linux**: installs `tmux`, `fzf`, `tree`, `micro`, `zsh-autosuggestions`,
  `zsh-syntax-highlighting` via `apt`. `starship`, `eza`, `yazi`, and the
  Nerd Font aren't reliably in apt repos, so those are fetched straight from
  upstream (official installer for starship, prebuilt release binaries for
  eza/yazi, font zip + `fc-cache` for the Nerd Font)
- Symlink `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf` and
  `tmux/scripts/` -> `~/.config/tmux/scripts/` (any real file already at
  those paths gets backed up with a `.bak.<timestamp>` suffix first)
- Symlink `yazi/keymap.toml` -> `~/.config/yazi/keymap.toml`
- Symlink `readline/inputrc` -> `~/.inputrc`
- Symlink `eza/theme.yml` -> `~/.config/eza/theme.yml`
- Add a line to `~/.zshrc` that sources `zsh/zshrc.dotfiles` (your existing
  `~/.zshrc` is otherwise untouched)
- Set `git config --global core.editor micro`
- Install [TPM](https://github.com/tmux-plugins/tpm) and all tmux plugins

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
| `Brewfile` | Packages installed by `install.sh` on macOS |
| `install.sh` | Bootstraps everything above (macOS via Homebrew, Linux via apt + upstream installers) |

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
