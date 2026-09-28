#!/bin/bash
# Amethyst-style layouts for the focused workspace.
#   cycle-layout.sh           -> switch to the next layout in the list
#   cycle-layout.sh <layout>  -> switch straight to <layout>
# Edit this list to change which layouts are included and in what order.
layouts=(fullscreen column custom)
main_ratio=60   # custom: % of the screen width taken by the focused window

ws=$(aerospace list-workspaces --focused)
state="${TMPDIR:-/tmp}/aerospace-layout-$ws"
current=$(cat "$state" 2>/dev/null)

next=${1:-}
if [ -z "$next" ]; then
  next=${layouts[0]}
  for i in "${!layouts[@]}"; do
    if [ "${layouts[$i]}" = "$current" ]; then
      next=${layouts[$(( (i + 1) % ${#layouts[@]} ))]}
    fi
  done
fi

aerospace flatten-workspace-tree
case $next in
  fullscreen) aerospace layout h_accordion ;;
  column)     aerospace layout h_tiles; aerospace balance-sizes ;;
  custom)
    # Focused window on the left, everything else stacked on the right
    aerospace layout v_tiles
    aerospace move left
    screen=$(aerospace list-monitors --focused --format '%{monitor-appkit-nsscreen-screens-id}')
    width=$(osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSScreen.screens.objectAtIndex($screen - 1).visibleFrame.size.width")
    # Split the space left after gaps (outer left/right + one inner gap)
    gap() { sed -nE "s/^gaps\.$1 *= *([0-9]+).*/\1/p" ~/.aerospace.toml; }
    usable=$(( ${width%.*} - $(gap outer.left) - $(gap outer.right) - $(gap inner.horizontal) ))
    aerospace resize width $(( usable * main_ratio / 100 ))
    ;;
esac
echo "$next" > "$state"
