# Shared by the other scripts (source it, don't run it): where state lives, and which
# monitor setup is connected.
#
# A "setup" is the set of connected monitors, e.g. Built-in_Retina_Display+C34J79x. Office, home
# desk and laptop-only each get their own, so each can remember its own arrangement.

state_dir="$HOME/.local/state/aerospace"
mkdir -p "$state_dir"

# One line per monitor, left to right: "<monitor-id>|<name>#<n>". n counts monitors with the same
# name, so two identical screens still get different keys
monitor_keys() {
  aerospace list-monitors --format '%{monitor-id}|%{monitor-name}' |
    sort -t'|' -k1,1n | awk -F'|' '{ print $1 "|" $2 "#" (++seen[$2]) }'
}

# Name of the connected setup. Pass monitor_keys output to avoid asking AeroSpace again
setup_id() {
  { if [ -n "$1" ]; then printf '%s\n' "$1"; else monitor_keys; fi; } |
    cut -d'|' -f2 | sed 's/#[0-9]*$//' | sort | paste -sd+ - | tr -c 'A-Za-z0-9+\n' '_'
}

# The setup whose saved state is in effect. Right after monitors change it still names the old
# setup until workspace-memory.sh has applied the new one
active_setup() {
  cat "$state_dir/setup" 2>/dev/null || setup_id
}
