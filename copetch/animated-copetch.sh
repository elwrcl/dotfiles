#!/usr/bin/env bash

delay=${1:-0.05}
cache_file="$HOME/.cache/copetch.txt"

mkdir -p ~/.cache
if [[ ! -f "$cache_file" || $(find "$cache_file" -mmin +60 2>/dev/null) ]]; then
  copetch > "$cache_file"
fi

mapfile -t fetch_lines < "$cache_file"
mapfile -t frames < <(ls -1 ~/.config/copetch/frames_colour/*.txt 2>/dev/null | sort)

[[ ${#frames[@]} -eq 0 ]] && { echo "No frames found in ~/.config/copetch/frames_colour/"; exit 1; }
frame_width=$(sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "${frames[0]}" | \
  awk '{ w=length($0); if (w>max) max=w } END { print max+0 }')
FETCH_COL=$((frame_width + 3))

current_frame_lines=()
FC=$((FETCH_COL + 1))

draw() {
  mapfile -t current_frame_lines < "$1"
  local nf=${#current_frame_lines[@]} nk=${#fetch_lines[@]}
  local rows=$(( nf > nk ? nf : nk ))
  local esc=$'\e'
  local buf=""
  buf+="${esc}[?2026h"

  for (( i=0; i<rows; i++ )); do
    buf+="${esc}[$((i+1));1H${esc}[K"
    (( i < nf )) && buf+="${current_frame_lines[$i]}"
    buf+="${esc}[$((i+1));${FC}H"
    (( i < nk )) && buf+="${fetch_lines[$i]}"
  done

  buf+="${esc}[$((rows + 1));1H"
  buf+="${esc}[?2026l"
  printf "%s" "$buf"
}

cleanup() {
  local nf=${#current_frame_lines[@]} nk=${#fetch_lines[@]}
  local total=$(( nf > nk ? nf : nk ))

  printf '\e[?2026l'
  printf '\e[%d;1H' $((total + 1))
  printf '\e[2 q'
  printf '\e[?25h'
}

trap cleanup EXIT INT TERM
printf '\e[?25l'
printf '\e[0 q'
clear

while true; do
  for frame in "${frames[@]}"; do
    draw "$frame"
    read -r -t "$delay" -n 1 && exit 0
  done
done
