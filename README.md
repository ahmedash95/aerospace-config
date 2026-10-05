# aerospace-config

My [AeroSpace](https://github.com/nikitabobko/AeroSpace) setup, tuned to feel like Amethyst: preset layouts you can cycle through, 10px gaps, no empty tiles for windows you can't see, and windows that stay on their workspaces when AeroSpace restarts.

[![Demo: switching layouts and workspaces](demo.gif)](demo.mp4)

*Click for the full-quality video.*

## Layouts

| Layout | What it looks like |
|---|---|
| **Fullscreen** | Every window fills the screen; switch between them with `alt-h` / `alt-l` |
| **Column** | All windows side by side at equal widths |
| **Rows** | All windows stacked top to bottom at equal heights |
| **Custom (60/40)** | Focused window takes the left 60%, the rest stack on the right 40%. A window that's alone on the workspace keeps the 60% size and the right side stays empty |

Layouts are applied on demand. A window opened later won't slot into the layout on its own, so press the shortcut again to re-apply it.

## Shortcuts

`opt` = Option/Alt.

| Keys | Action |
|---|---|
| `opt+ctrl+←` | Cycle to the next layout (Fullscreen → Column → Rows → Custom) |
| `opt+ctrl+f` | Fullscreen |
| `opt+ctrl+c` | Column |
| `opt+ctrl+r` | Rows |
| `opt+ctrl+m` | Custom 60/40 (the focused window becomes the big one) |
| `cmd+opt+ctrl+←` | Move the focused window to the next position (wraps around) |
| `opt+1…9`, `opt+a…z` | Switch to that workspace |
| `opt+shift+1…9`, `opt+shift+a…z` | Send the focused window to that workspace |
| `opt+h/j/k/l` | Focus left / down / up / right |
| `opt+shift+h/j/k/l` | Move the window left / down / up / right |
| `opt+shift+;` | Service mode (`esc` there reloads the config) |

The letters H, J, K and L aren't workspaces, because those keys are used for focus and movement. Everything not listed above uses AeroSpace's defaults.

## Files

This repo is meant to be cloned as `~/.config/aerospace`, the folder where AeroSpace looks for its config. Nothing needs to be linked or copied.

```
aerospace.toml                 AeroSpace config
install.sh                     installer / updater (see below)
scripts/cycle-layout.sh        layout switching
scripts/hide-ghost-windows.sh  keeps invisible windows from taking tiles
scripts/workspace-memory.sh    restores windows to their workspaces after a restart
```

- **`cycle-layout.sh`** switches between the layouts. It remembers the current layout for each workspace, so cycling picks up where you left off. The `layouts=(...)` line at the top sets which layouts are in the cycle and in what order. `main_ratio` sets the Custom split, and the script takes gap sizes from `aerospace.toml` into account.
- **`hide-ghost-windows.sh`** runs on every focus and workspace change. AeroSpace still gives a tile to windows macOS isn't drawing: inactive native tabs, minimized windows and windows on another macOS Space. That leaves empty space in the layout. The script floats those windows so they stop taking space, and tiles them again once they're visible.
- **`workspace-memory.sh`** puts windows back on their workspaces after AeroSpace restarts. Normally AeroSpace only tracks this while it's running, so a restart piles every window onto one workspace. The script saves which workspace each window is on whenever focus or the workspace changes, and every 3 seconds as a backup, because moving a window that isn't focused doesn't trigger any callback. On startup it moves each window back, matching by window ID, then by app and window title, then by the app's last workspace. The last match also places apps after a reboot or relaunch, when window IDs change. State is kept in `~/.local/state/aerospace/`, and `restore.log` there lists what each restore moved. Only which workspace a window is on is restored. AeroSpace has no command to save or load the layout tree, so window order and sizes within a workspace aren't restored.

## Setting up a new Mac

```sh
curl -fsSL https://raw.githubusercontent.com/ahmedash95/aerospace-config/main/install.sh | bash
```

The installer:
- Installs AeroSpace and [JankyBorders](https://github.com/FelixKratz/JankyBorders) (the border around the focused window) with Homebrew if they're missing. Set `NO_BREW=1` to skip this.
- Clones this repo to `~/.config/aerospace`, the folder where AeroSpace looks for its config. If the repo is already there, it pulls the latest version instead, so the same command also updates.
- Renames anything it would replace, such as an existing `~/.config/aerospace` or `~/.aerospace.toml`, to `*.bak-<timestamp>`. AeroSpace won't start when a config file exists in both places.
- Reloads AeroSpace's config if it's running, or starts it.

The first time AeroSpace starts, grant it Accessibility access (System Settings → Privacy & Security → Accessibility). To have it start at login, set `start-at-login = true` in `aerospace.toml`.

<details>
<summary>Manual install</summary>

```sh
brew install --cask nikitabobko/tap/aerospace
brew install FelixKratz/formulae/borders   # optional
mv ~/.aerospace.toml ~/.aerospace.toml.bak 2>/dev/null
git clone https://github.com/ahmedash95/aerospace-config.git ~/.config/aerospace
open -a AeroSpace
```

</details>

If macOS asks whether `osascript` may control your computer, allow it. The scripts use it to check which windows are on screen and how wide the screen is.

Editing the repo changes your live config. After you edit `aerospace.toml`, run `aerospace reload-config` or press `opt+shift+;` then `esc`.

## Tips

- **Avoid native tabs.** Every macOS tab counts as a separate window in AeroSpace. A tab group split across workspaces makes switching slow, with windows flashing and sliding into place. In Ghostty you can make `cmd+t` open a window instead:
  ```
  # ~/.config/ghostty/config
  keybind = cmd+t=new_window
  ```
- **Change the gaps** with the `gaps.inner.*` and `gaps.outer.*` values in `aerospace.toml`. They're currently 10px.
