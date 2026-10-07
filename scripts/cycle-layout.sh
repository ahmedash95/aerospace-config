#!/bin/bash
# Amethyst-style layouts, remembered per workspace and per monitor setup.
#   cycle-layout.sh            -> switch the focused workspace to the next layout in the list
#   cycle-layout.sh <layout>   -> switch the focused workspace straight to <layout>
#   cycle-layout.sh apply <ws> -> re-apply <ws>'s remembered layout, also when <ws> isn't focused
#                                 (called by workspace-memory.sh after restarts, monitor changes and new windows)
#   cycle-layout.sh sync       -> keep the custom layout in shape as windows open/close
#                                 (called from hide-ghost-windows.sh)
#   cycle-layout.sh forget     -> stop re-applying a layout to the focused workspace, because you
#                                 arranged it by hand (called from the manual layout bindings)
# A layout you pick is remembered for the connected monitor setup (see state.sh). In a setup where
# you never picked one for that workspace, the last one you picked anywhere is used.
# Edit this list to change which layouts are included and in what order.
layouts=(fullscreen column rows custom)
main_ratio=60   # custom: % of the screen width taken by the main window

source "$(dirname "$0")/state.sh"
setup_dir="$state_dir/setups/$(active_setup)"
mkdir -p "$setup_dir"

focused_ws=$(aerospace list-workspaces --focused)
if [ "$1" = apply ]; then ws=$2; else ws=$focused_ws; fi
[ -n "$ws" ] || exit 0
current=$(cat "$setup_dir/layout-$ws" 2>/dev/null || cat "$state_dir/layout-$ws" 2>/dev/null)
# custom: the big window, and a lone window we floated into the left column so the right side stays empty
main_state="$state_dir/main-$ws"
solo_state="${TMPDIR:-/tmp}/aerospace-custom-solo-$ws"
solo=$(cat "$solo_state" 2>/dev/null)

# New windows, focus changes and monitor changes can all land here at once; take turns
lock="${TMPDIR:-/tmp}/aerospace-layout.lock"
for _ in {1..30}; do mkdir "$lock" 2>/dev/null && break; sleep 0.1; done
trap 'rmdir "$lock" 2>/dev/null' EXIT

gap() { sed -nE "s/^gaps\.$1 *= *([0-9]+).*/\1/p" ~/.config/aerospace/aerospace.toml; }

# AppKit screen number of the monitor this workspace is on
screen() {
  aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}' |
    awk -F'|' -v ws="$ws" '$1 == ws { print $2 }'
}

tiled_windows() {
  aerospace list-windows --workspace "$ws" --format '%{window-id} %{window-layout}' | awk '$2 != "floating" { print $1 }'
}

# Window $1 on the left, everything else stacked on the right
arrange_custom() {
  aerospace layout --workspace "$ws" --root v_tiles
  aerospace move --window-id "$1" left
  width=$(osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSScreen.screens.objectAtIndex($(screen) - 1).visibleFrame.size.width")
  # Split the space left after gaps (outer left/right + one inner gap)
  usable=$(( ${width%.*} - $(gap outer.left) - $(gap outer.right) - $(gap inner.horizontal) ))
  aerospace resize --window-id "$1" width $(( usable * main_ratio / 100 ))
  echo "$1" > "$main_state"
}

# Tiles always fill the screen, so a single window is floated and pinned
# to the same spot it would have as the main tile, leaving the rest empty
place_solo() {
  aerospace focus --window-id "$1"
  aerospace layout --window-id "$1" floating
  pid=$(aerospace list-windows --focused --format '%{app-pid}')
  osascript -l JavaScript -e "
    ObjC.import('AppKit');
    const screens = \$.NSScreen.screens;
    const vf = screens.objectAtIndex($(screen) - 1).visibleFrame;
    const top = screens.objectAtIndex(0).frame.size.height - vf.origin.y - vf.size.height;
    const usable = vf.size.width - $(gap outer.left) - $(gap outer.right) - $(gap inner.horizontal);
    const win = Application('System Events').processes.whose({unixId: $pid})[0].windows[0];
    win.position = [vf.origin.x + $(gap outer.left), top + $(gap outer.top)];
    win.size = [Math.floor(usable * $main_ratio / 100), vf.size.height - $(gap outer.top) - $(gap outer.bottom)];
  " >/dev/null
  echo "$1" > "$solo_state"
}

# Hand the lone window back to the tiling tree
release_solo() {
  [ -n "$solo" ] && aerospace layout --window-id "$solo" tiling 2>/dev/null
  rm -f "$solo_state"
  solo=""
}

# Lay the workspace out as $1. For custom, $2 is the big window (falls back to any tiled window)
apply_layout() {
  release_solo
  aerospace flatten-workspace-tree --workspace "$ws"
  case $1 in
    fullscreen) aerospace layout --workspace "$ws" --root h_accordion ;;
    column)     aerospace layout --workspace "$ws" --root h_tiles; aerospace balance-sizes --workspace "$ws" ;;
    rows)       aerospace layout --workspace "$ws" --root v_tiles; aerospace balance-sizes --workspace "$ws" ;;
    custom)
      tiled=$(tiled_windows)
      case $(grep -c . <<<"$tiled") in
        0) ;;
        # Pinning needs focus; a hidden workspace gets it from sync once you switch to it
        1) [ "$ws" = "$focused_ws" ] && place_solo "$tiled" ;;
        *) main=$2
           grep -qx "$main" <<<"$tiled" || main=$(head -1 <<<"$tiled")
           arrange_custom "$main" ;;
      esac
      ;;
  esac
}

case $1 in
  sync)
    [ "$current" = custom ] || exit 0
    windows=$(aerospace list-windows --workspace "$ws" --format '%{window-id} %{window-layout}')
    others=$(awk -v s="$solo" '$1 != s && $2 != "floating" { print $1 }' <<<"$windows")
    count=$(grep -c . <<<"$others")
    if [ -n "$solo" ] && grep -q "^$solo " <<<"$windows"; then
      if [ "$count" -eq 0 ]; then
        # Still alone: re-pin it if something tiled it again (e.g. after un-minimizing)
        grep -qx "$solo floating" <<<"$windows" || place_solo "$solo"
      else
        # Another window arrived: tile the lone window back in as the main one
        apply_layout custom "$solo"
      fi
    else
      release_solo
      [ "$count" -eq 1 ] && place_solo "$others"
    fi
    exit 0
    ;;
  apply)
    [ -n "$current" ] && apply_layout "$current" "$(cat "$main_state" 2>/dev/null)"
    exit 0
    ;;
  forget)
    release_solo
    rm -f "$setup_dir/layout-$ws" "$state_dir/layout-$ws"
    exit 0
    ;;
esac

next=${1:-}
if [ -z "$next" ]; then
  next=${layouts[0]}
  for i in "${!layouts[@]}"; do
    if [ "${layouts[$i]}" = "$current" ]; then
      next=${layouts[$(( (i + 1) % ${#layouts[@]} ))]}
    fi
  done
fi

apply_layout "$next" "$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)"
echo "$next" > "$setup_dir/layout-$ws"
echo "$next" > "$state_dir/layout-$ws"
