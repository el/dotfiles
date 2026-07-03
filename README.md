# dotfiles

Personal terminal setup: tmux, yazi, zsh, and git config, with a single
install script to bootstrap a new Mac.

## Install on a new machine

```sh
git clone https://github.com/el/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
./install.sh
```

The script is safe to re-run. It will:

- Install [Homebrew](https://brew.sh) if missing
- Install packages from [`Brewfile`](Brewfile): `tmux`, `fzf`, `tree`,
  `yazi`, `micro`, and the JetBrains Mono Nerd Font
- Symlink `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf` and
  `tmux/scripts/` -> `~/.config/tmux/scripts/` (any real file already at
  those paths gets backed up with a `.bak.<timestamp>` suffix first)
- Symlink `yazi/keymap.toml` -> `~/.config/yazi/keymap.toml`
- Symlink `readline/inputrc` -> `~/.inputrc`
- Add a line to `~/.zshrc` that sources `zsh/zshrc.dotfiles` (your existing
  `~/.zshrc` is otherwise untouched)
- Set `git config --global core.editor micro`
- Install [TPM](https://github.com/tmux-plugins/tpm) and all tmux plugins

After it finishes: open a new terminal (or `source ~/.zshrc`), set your
terminal's font to **JetBrainsMono Nerd Font** (needed for the status bar
icons — e.g. in iTerm2: Preferences > Profiles > Text), then start tmux.

## What's in here

| Path | Purpose |
|---|---|
| `tmux/tmux.conf` | Full tmux config |
| `tmux/scripts/` | Helper scripts tmux/yazi shell out to |
| `yazi/keymap.toml` | Custom yazi keybindings |
| `zsh/zshrc.dotfiles` | `EDITOR`/`VISUAL` — sourced from `~/.zshrc` |
| `readline/inputrc` | Arrow keys do prefix-based history search |
| `Brewfile` | Packages installed by `install.sh` |
| `install.sh` | Bootstraps everything above |

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
