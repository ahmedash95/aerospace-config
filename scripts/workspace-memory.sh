#!/bin/bash
# Remember where windows, workspaces and layouts belong, and put them back.
#   workspace-memory.sh save     - snapshot window -> workspace placement, and which monitor each
#                                  workspace is on in the current setup (run from focus/workspace callbacks)
#   workspace-memory.sh watch    - keep snapshotting every few seconds while AeroSpace runs, to catch
#                                  moves that fire no callback, and re-apply a setup's arrangement when
#                                  monitors are plugged in or out (run from after-startup-command)
#   workspace-memory.sh restore  - move windows back, then workspaces and layouts
#                                  (run from after-startup-command)
#   workspace-memory.sh place    - send a newly opened window to its app's workspace and re-apply that
#                                  workspace's layout (run from on-window-detected)
# Matching on restore: same window id + app, else same app + title, else the app's last workspace.
# The app fallback also covers reboots / app relaunches, where window ids change.
#
# Window -> workspace placement is shared by every setup (office, home desk, laptop only). Which
# monitor each workspace shows on, and each workspace's layout (cycle-layout.sh), are kept per setup.

# Apps whose new windows stay on the workspace you open them from instead of joining the app's
# other windows. Use bundle ids, e.g. (com.apple.finder com.mitchellh.ghostty)
roaming_apps=()

source "$(dirname "$0")/state.sh"
dir="$state_dir"
snap="$dir/workspaces"
marker="$dir/restored-pid"
log="$dir/restore.log"
cycle_layout="$(dirname "$0")/cycle-layout.sh"
fmt='%{window-id}|%{app-bundle-id}|%{workspace}|%{window-title}'
# -a: callbacks are children of AeroSpace, and pgrep skips its own ancestors by default
server_pid=$(pgrep -ax AeroSpace | head -1)

# Right after a restart every window sits on one workspace; nothing gets saved or moved
# until restore has run for this AeroSpace process
restored() {
  [ -n "$server_pid" ] && [ "$(cat "$marker" 2>/dev/null)" = "$server_pid" ]
}

# Replace <file> with stdin, unless nothing changed
write_if_changed() {
  tmp=$(mktemp "$1.XXXXXX")
  cat > "$tmp"
  if cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
}

save() {
  restored || return 0
  current=$(aerospace list-windows --all --format "$fmt") || return 0
  [ -n "$current" ] || return 0
  running=$(cut -d'|' -f2 <<<"$current" | sort -u)
  {
    printf '%s\n' "$current"
    # Keep entries for apps that aren't open right now so they land in the right place when reopened
    [ -f "$snap" ] && while IFS='|' read -r id app ws title; do
      grep -qxF "$app" <<<"$running" || printf '%s|%s|%s|%s\n' "$id" "$app" "$ws" "$title"
    done < "$snap"
  } | write_if_changed "$snap"
  save_monitors
}

# Which monitor every workspace is on and which ones are showing, for the connected setup.
# Skipped until a monitor change has been applied, so AeroSpace's own reshuffle doesn't overwrite it
save_monitors() {
  keys=$(monitor_keys)
  setup=$(setup_id "$keys")
  [ -n "$setup" ] && [ "$setup" = "$(cat "$dir/setup" 2>/dev/null)" ] || return 0
  mkdir -p "$dir/setups/$setup"
  aerospace list-workspaces --all --format '%{workspace}|%{monitor-id}|%{workspace-is-visible}' |
    awk -F'|' 'NR == FNR { key[$1] = $2; next } { print $1 "|" key[$2] "|" $3 }' <(printf '%s\n' "$keys") - |
    write_if_changed "$dir/setups/$setup/monitors"
}

# Put every workspace back on the monitor it had in <setup>, with the ones that were showing on top,
# then re-apply every workspace's layout. A setup seen for the first time just starts being remembered
apply_setup() {
  setup=$1
  map="$dir/setups/$setup/monitors"
  if [ -s "$map" ]; then
    focused_window=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
    focused_workspace=$(aerospace list-workspaces --focused)
    # Hidden workspaces first: moving one shows it on its monitor and pushes off whatever was there,
    # so the ones that belong on top are then switched to (moving them alone is a no-op when they
    # already live on that monitor)
    cmds=$(awk -F'|' '
      FNR == 1 { file++ }
      file == 1 { monitor[$2] = $1; next }
      file == 2 { now[$1] = $2; next }
      $2 in monitor {
        cmd = "move-workspace-to-monitor --workspace \047" $1 "\047 " monitor[$2]
        if ($3 == "true") shown = shown cmd "; workspace \047" $1 "\047; "
        else if (now[$1] != monitor[$2]) hidden = hidden cmd "; "
      }
      END { all = hidden shown; sub(/; $/, "", all); print all }
    ' <(monitor_keys) <(aerospace list-workspaces --all --format '%{workspace}|%{monitor-id}') "$map")
    # One eval, so AeroSpace redraws once instead of after every move
    [ -n "$cmds" ] && aerospace eval "$cmds"
    if [ -n "$focused_window" ]; then
      aerospace focus --window-id "$focused_window"
    else
      aerospace workspace "$focused_workspace"
    fi
    echo "$(date '+%F %T') setup $setup: $(grep -o 'move-workspace' <<<"$cmds" | grep -c .) workspace moves" >> "$log"
  else
    echo "$(date '+%F %T') setup $setup: first time seen, remembering it from now on" >> "$log"
  fi
  echo "$setup" > "$dir/setup"
  aerospace list-windows --all --format '%{workspace}' | sort -u | while read -r ws; do
    "$cycle_layout" apply "$ws"
  done
}

watch() {
  lock="$dir/watch.pid"
  # One watcher per AeroSpace process
  other=$(cat "$lock" 2>/dev/null)
  [ -n "$other" ] && kill -0 "$other" 2>/dev/null && exit 0
  echo $$ > "$lock"
  pending=""
  tick=0
  while kill -0 "$server_pid" 2>/dev/null; do
    if restored; then
      setup=$(setup_id)
      if [ -n "$setup" ] && [ "$setup" != "$(cat "$dir/setup" 2>/dev/null)" ]; then
        # Monitors show up in stages while they connect or wake; act once two checks agree
        if [ "$setup" = "$pending" ]; then
          apply_setup "$setup"
          pending=""
        else
          pending=$setup
        fi
      else
        pending=""
      fi
      (( tick++ % 3 )) || save
    fi
    sleep 1
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
  apply_setup "$(setup_id)"
  printf '%s' "$server_pid" > "$marker"
}

# Where a new window of <app> belongs: next to the app's open windows when they're all on one
# workspace, else where the app was last seen. Stays put when the app is already on this workspace
# or spread over several
place() {
  id=$AEROSPACE_WINDOW_ID
  # Without this, AeroSpace would treat the new window as the focused one in every command below
  unset AEROSPACE_WINDOW_ID AEROSPACE_WORKSPACE
  [ -n "$id" ] && restored || return 0
  windows=$(aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}|%{workspace}|%{window-layout}')
  IFS='|' read -r _ app ws layout < <(grep "^$id|" <<<"$windows")
  # Dialogs and other floating windows stay where macOS put them
  [ -n "$app" ] && [ "$layout" != floating ] || return 0
  target=$ws
  if ! printf '%s\n' "${roaming_apps[@]}" | grep -qxF "$app"; then
    target=$(awk -F'|' -v id="$id" -v app="$app" -v ws="$ws" '
      FNR == 1 { file++ }
      $2 != app || $1 == id { next }
      file == 1 { open[$3]++; anyopen = 1 }
      file == 2 { seen[$3]++ }
      END {
        if (anyopen) {
          if (ws in open) { print ws; exit }
          for (w in open) { n++; only = w }
          print (n == 1 ? only : ws); exit
        }
        best = ws
        for (w in seen) if (seen[w] > seen[best]) best = w
        print best
      }' <(printf '%s\n' "$windows") "$snap" 2>/dev/null)
    [ -n "$target" ] || target=$ws
  fi
  if [ "$target" != "$ws" ]; then
    focused_app=$(aerospace list-windows --focused --format '%{app-bundle-id}' 2>/dev/null)
    aerospace move-node-to-workspace --window-id "$id" "$target" &&
      echo "$(date '+%F %T') new window $app ($id): $ws -> $target" >> "$log"
    # You just opened it, so follow it there
    [ "$focused_app" = "$app" ] && aerospace focus --window-id "$id"
  fi
  "$cycle_layout" apply "$target"
  save
}

case "$1" in
  save) save ;;
  watch) watch ;;
  restore) restore ;;
  place) place ;;
  *) echo "usage: $0 save|watch|restore|place" >&2; exit 1 ;;
esac
