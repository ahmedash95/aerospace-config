#!/bin/bash
# Remember which workspace every window lives on and put them back after AeroSpace restarts.
#   workspace-memory.sh save     - snapshot current placement (run from focus/workspace callbacks)
#   workspace-memory.sh watch    - keep snapshotting every few seconds while AeroSpace runs, to catch
#                                  moves that fire no callback (run from after-startup-command)
#   workspace-memory.sh restore  - move windows back (run from after-startup-command)
# Matching on restore: same window id + app, else same app + title, else the app's last workspace.
# The app fallback also covers reboots / app relaunches, where window ids change.

dir="$HOME/.local/state/aerospace"
snap="$dir/workspaces"
marker="$dir/restored-pid"
log="$dir/restore.log"
mkdir -p "$dir"
fmt='%{window-id}|%{app-bundle-id}|%{workspace}|%{window-title}'
# -a: callbacks are children of AeroSpace, and pgrep skips its own ancestors by default
server_pid=$(pgrep -ax AeroSpace | head -1)

save() {
  # Right after a restart every window sits on one workspace; don't overwrite the
  # snapshot with that until restore has run for this AeroSpace process
  [ -n "$server_pid" ] && [ "$(cat "$marker" 2>/dev/null)" = "$server_pid" ] || return 0
  current=$(aerospace list-windows --all --format "$fmt") || return 0
  [ -n "$current" ] || return 0
  running=$(cut -d'|' -f2 <<<"$current" | sort -u)
  tmp=$(mktemp "$snap.XXXXXX")
  {
    printf '%s\n' "$current"
    # Keep entries for apps that aren't open right now so they land in the right place when reopened
    [ -f "$snap" ] && while IFS='|' read -r id app ws title; do
      grep -qxF "$app" <<<"$running" || printf '%s|%s|%s|%s\n' "$id" "$app" "$ws" "$title"
    done < "$snap"
  } > "$tmp"
  if cmp -s "$tmp" "$snap"; then rm -f "$tmp"; else mv "$tmp" "$snap"; fi
}

watch() {
  lock="$dir/watch.pid"
  # One watcher per AeroSpace process
  other=$(cat "$lock" 2>/dev/null)
  [ -n "$other" ] && kill -0 "$other" 2>/dev/null && exit 0
  echo $$ > "$lock"
  while kill -0 "$server_pid" 2>/dev/null; do
    save
    sleep 3
  done
}

restore_pass() {
  [ -f "$snap" ] || return 0
  while IFS='|' read -r id app ws title; do
    [ -n "$id" ] || continue
    target=$(awk -F'|' -v id="$id" -v app="$app" -v title="$title" '
      $1 == id && $2 == app { byid = $3 }
      $2 == app && substr($0, length($1 $2 $3) + 4) == title && !bytitle { bytitle = $3 }
      $2 == app && !byapp { byapp = $3 }
      END { print byid ? byid : bytitle ? bytitle : byapp }' "$snap")
    if [ -n "$target" ] && [ "$target" != "$ws" ]; then
      aerospace move-node-to-workspace --window-id "$id" "$target" &&
        echo "$(date '+%F %T') $app ($id): $ws -> $target" >> "$log"
    fi
  done < <(aerospace list-windows --all --format "$fmt")
}

restore() {
  echo "$(date '+%F %T') restore for AeroSpace pid ${server_pid:-?}" >> "$log"
  # AeroSpace may still be discovering existing windows; a second pass catches stragglers
  sleep 1; restore_pass
  sleep 2; restore_pass
  printf '%s' "$server_pid" > "$marker"
}

case "$1" in
  save) save ;;
  watch) watch ;;
  restore) restore ;;
  *) echo "usage: $0 save|watch|restore" >&2; exit 1 ;;
esac
