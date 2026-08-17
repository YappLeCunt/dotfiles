#!/usr/bin/env bash
# downloads-notify.sh — desktop notification when a new file lands in ~/Downloads
# Watches close_write (file fully written) and moved_to (file renamed/moved in).
# Skips temp/browser partials, dotfiles, directories. Dedupes renames (3s window).
# Works for KDE Connect, RQuickShare, browser downloads, anything writing there.

DIR="${1:-$HOME/Downloads}"
DEBOUNCE=3
declare -A seen

while read -r _ file; do
    [[ -n "$file" ]] || continue   # ignore dir-level events

    case "$file" in
        .*|*.part|*.crdownload|*.tmp|*.partial) continue ;;
    esac

    [[ -f "$DIR/$file" ]] || continue   # not a regular file (dirs, dead links)

    now=$(date +%s)
    if [[ -n "${seen[$file]}" ]] && (( now - seen[$file] < DEBOUNCE )); then
        continue
    fi
    seen[$file]=$now

    notify-send -a "Downloads" -i folder-download "New file received" "$file"
done < <(inotifywait -m -q -e close_write -e moved_to --format '%e %f' "$DIR")
