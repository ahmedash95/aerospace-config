#!/bin/bash
# Amethyst-style layouts for the focused workspace.
#   cycle-layout.sh           -> switch to the next layout in the list
#   cycle-layout.sh <layout>  -> switch straight to <layout>
#   cycle-layout.sh sync      -> keep the custom layout in shape as windows open/close
#                                (called from hide-ghost-windows.sh)
# Edit this list to change which layouts are included and in what order.
layouts=(fullscreen column rows custom)
main_ratio=60   # custom: % of the screen width taken by the focused window

ws=$(aerospace list-workspaces --focused)
state="${TMPDIR:-/tmp}/aerospace-layout-$ws"
# custom: a lone window we floated into the left column so the right side stays empty
solo_state="${TMPDIR:-/tmp}/aerospace-custom-solo-$ws"
current=$(cat "$state" 2>/dev/null)
solo=$(cat "$solo_state" 2>/dev/null)

gap() { sed -nE "s/^gaps\.$1 *= *([0-9]+).*/\1/p" ~/.aerospace.toml; }

# Focused window on the left, everything else stacked on the right
arrange_custom() {
  aerospace flatten-workspace-tree
  aerospace layout v_tiles
  aerospace move left
  screen=$(aerospace list-monitors --focused --format '%{monitor-appkit-nsscreen-screens-id}')
  width=$(osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSScreen.screens.objectAtIndex($screen - 1).visibleFrame.size.width")
  # Split the space left after gaps (outer left/right + one inner gap)
  usable=$(( ${width%.*} - $(gap outer.left) - $(gap outer.right) - $(gap inner.horizontal) ))
  aerospace resize width $(( usable * main_ratio / 100 ))
}

# Tiles always fill the screen, so a single window is floated and pinned
# to the same spot it would have as the main tile, leaving the rest empty
place_solo() {
  aerospace focus --window-id "$1"
  aerospace layout --window-id "$1" floating
  pid=$(aerospace list-windows --focused --format '%{app-pid}')
  screen=$(aerospace list-monitors --focused --format '%{monitor-appkit-nsscreen-screens-id}')
  osascript -l JavaScript -e "
    ObjC.import('AppKit');
    const screens = \$.NSScreen.screens;
    const vf = screens.objectAtIndex($screen - 1).visibleFrame;
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
}

if [ "$1" = sync ]; then
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
      focused=$(aerospace list-windows --focused --format '%{window-id}')
      release_solo
      aerospace focus --window-id "$solo"
      arrange_custom
      aerospace focus --window-id "$focused"
    fi
  else
    release_solo
    [ "$count" -eq 1 ] && place_solo "$others"
  fi
  exit 0
fi

next=${1:-}
if [ -z "$next" ]; then
  next=${layouts[0]}
  for i in "${!layouts[@]}"; do
    if [ "${layouts[$i]}" = "$current" ]; then
      next=${layouts[$(( (i + 1) % ${#layouts[@]} ))]}
    fi
  done
fi

release_solo
aerospace flatten-workspace-tree
case $next in
  fullscreen) aerospace layout h_accordion ;;
  column)     aerospace layout h_tiles; aerospace balance-sizes ;;
  rows)       aerospace layout v_tiles; aerospace balance-sizes ;;
  custom)
    tiled=$(aerospace list-windows --workspace "$ws" --format '%{window-id} %{window-layout}' | awk '$2 != "floating" { print $1 }')
    if [ "$(grep -c . <<<"$tiled")" -eq 1 ]; then
      place_solo "$tiled"
    else
      arrange_custom
    fi
    ;;
esac
echo "$next" > "$state"
