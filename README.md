# aerospace-config

My [AeroSpace](https://github.com/nikitabobko/AeroSpace) setup, tuned to feel like Amethyst: preset layouts you can cycle through, 10px gaps, and no empty tiles for windows you can't see.

## Layouts

| Layout | What it looks like |
|---|---|
| **Fullscreen** | Every window fills the screen; switch between them with `alt-h` / `alt-l` |
| **Column** | All windows side by side at equal widths |
| **Custom (60/40)** | Focused window takes the left 60%, the rest stack on the right 40% |

Layouts are applied on demand. A window opened later won't slot into the layout on its own, so press the shortcut again to re-apply it.

## Shortcuts

`opt` = Option/Alt.

| Keys | Action |
|---|---|
| `opt+ctrl+←` | Cycle to the next layout (Fullscreen → Column → Custom) |
| `opt+ctrl+f` | Fullscreen |
| `opt+ctrl+c` | Column |
| `opt+ctrl+m` | Custom 60/40 (the focused window becomes the big one) |
| `cmd+opt+ctrl+←` | Move the focused window to the next position (wraps around) |
| `opt+1…9`, `opt+a…z` | Switch to that workspace |
| `opt+shift+1…9`, `opt+shift+a…z` | Send the focused window to that workspace |
| `opt+h/j/k/l` | Focus left / down / up / right |
| `opt+shift+h/j/k/l` | Move the window left / down / up / right |
| `opt+shift+;` | Service mode (`esc` there reloads the config) |

The letters H, J, K and L aren't workspaces, because those keys are used for focus and movement. Everything not listed above uses AeroSpace's defaults.

## Files

```
aerospace.toml                 -> ~/.aerospace.toml
scripts/cycle-layout.sh        -> ~/.config/aerospace/cycle-layout.sh
scripts/hide-ghost-windows.sh  -> ~/.config/aerospace/hide-ghost-windows.sh
install.sh                     links the files above into place
```

- **`cycle-layout.sh`** switches between the layouts. It remembers the current layout for each workspace, so cycling picks up where you left off. The `layouts=(...)` line at the top sets which layouts are in the cycle and in what order. `main_ratio` sets the Custom split, and the script takes gap sizes from `aerospace.toml` into account.
- **`hide-ghost-windows.sh`** runs on every focus and workspace change. AeroSpace still gives a tile to windows macOS isn't drawing: inactive native tabs, minimized windows and windows on another macOS Space. That leaves empty space in the layout. The script floats those windows so they stop taking space, and tiles them again once they're visible.

## Setting up a new Mac

1. Install AeroSpace:
   ```sh
   brew install --cask nikitabobko/tap/aerospace
   ```
2. Open AeroSpace once and grant it Accessibility access (System Settings → Privacy & Security → Accessibility).
3. Clone this repo and run the installer:
   ```sh
   git clone git@github.com:ahmedash95/aerospace-config.git ~/Code/aerospace-config
   ~/Code/aerospace-config/install.sh
   ```
   The installer symlinks the files into place, so editing the repo changes your live config. Any existing files it replaces are kept as `*.bak-<timestamp>`.
4. **Optional:** set `start-at-login = true` in `aerospace.toml` so AeroSpace starts at login.

If macOS asks whether `osascript` may control your computer, allow it. The scripts use it to check which windows are on screen and how wide the screen is.

After you edit `aerospace.toml`, run `aerospace reload-config` or press `opt+shift+;` then `esc`.

## Tips

- **Avoid native tabs.** Every macOS tab counts as a separate window in AeroSpace. A tab group split across workspaces makes switching slow, with windows flashing and sliding into place. In Ghostty you can make `cmd+t` open a window instead:
  ```
  # ~/.config/ghostty/config
  keybind = cmd+t=new_window
  ```
- **Change the gaps** with the `gaps.inner.*` and `gaps.outer.*` values in `aerospace.toml`. They're currently 10px.
