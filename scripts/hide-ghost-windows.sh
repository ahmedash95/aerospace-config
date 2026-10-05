#!/bin/bash
# Keep AeroSpace from reserving tiles for windows that aren't actually drawn
# (inactive native tabs, minimized windows, windows on another macOS Space).
# Invisible tiled windows are floated; once visible again they are tiled back.

state="${TMPDIR:-/tmp}/aerospace-ghost-windows"
lock="$state.lock"
dirty="$state.dirty"
touch "$state" "$dirty"
# If a run is already in progress it will notice the dirty flag and run again
mkdir "$lock" 2>/dev/null || exit 0
trap 'rmdir "$lock"' EXIT

while [ -e "$dirty" ]; do
rm -f "$dirty"
# Give macOS time to finish swapping tabs / (un)minimizing before we look
sleep 0.3

onscreen=$(osascript -l JavaScript -e '
ObjC.import("CoreGraphics");
const l = ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements, 0));
const ids = [];
for (let i = 0; i < l.count; i++) { const w = l.objectAtIndex(i); if (w.objectForKey("kCGWindowLayer").intValue === 0) ids.push(w.objectForKey("kCGWindowNumber").intValue); }
ids.join("\n")')
[ -n "$onscreen" ] || continue

ghosts=""
while read -r id layout; do
  [ -n "$id" ] || continue
  if grep -qx "$id" <<<"$onscreen"; then
    # Visible again: re-tile it if we were the ones who floated it
    if grep -qx "$id" "$state"; then
      aerospace layout --window-id "$id" tiling
    fi
  else
    ghosts+="$id"$'\n'
    [ "$layout" != floating ] && aerospace layout --window-id "$id" floating
  fi
done < <(aerospace list-windows --workspace visible --format '%{window-id} %{window-layout}')

printf '%s' "$ghosts" > "$state"

# Keep the custom layout's empty space when only one window is left
~/.config/aerospace/scripts/cycle-layout.sh sync
done
