# wpm plugin
#
# Typing speed test available within ZSH
#
# See the README for documentation.

# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

_OMZ_WPM_PLUGIN_DIR="${0:h}"

source "$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/wpm.utils.zsh"

# Starts a typing speed test
#
# wpm_test <seconds>
#
function wpm_test() {
  local test_duration=${1:-60}  # Default to 60 if not provided

  zsh "$_OMZ_WPM_PLUGIN_DIR/wpm.zsh" "$_OMZ_WPM_PLUGIN_DIR" "$test_duration"
}

# Shows a list of results from the stats folder
#
# wpm_history
#
function wpm_history() {
  local stats_file="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"

  if [[ -f "$stats_file" ]]; then
    local stats=$(_load_stats)
    local value_width=20
    local result_table_width=40
    local label_max_width=$((result_table_width - value_width - 5))
    local stats_array=("History" "═" "")
    declare -A stats_lists

    for file_name in $(echo "$stats" | jq -r 'keys[]'); do
      stats_array+=("-" "$(printf "$file_name")" "-")
      entries=$(echo "$stats" | jq -c ".\"$file_name\"[]")

      # Build each entry as an associative array and store it in stats_lists
      while read -r entry; do
          date=$(echo "$entry" | jq -r '.date')
          wpm=$(echo "$entry" | jq -r '.wpm')
          test_duration=$(echo "$entry" | jq -r '.["test duration"]')
          keystrokes=$(echo "$entry" | jq -r '.keystrokes')
          accuracy=$(echo "$entry" | jq -r '.accuracy')
          correct=$(echo "$entry" | jq -r '.correct')
          incorrect=$(echo "$entry" | jq -r '.incorrect')

          stats_array+=(
            ""
            "$date"
            "$(printf ' %-*s %*s ' "$label_max_width" "Speed" "$value_width" "$wpm "WPM)"
            "$(printf ' %-*s %*s ' "$label_max_width" "Timer" "$value_width" "$test_duration"s)"
            "$(printf ' %-*s %*s ' "$label_max_width" "Accuracy" "$value_width" "$accuracy"%)"
            "$(printf ' %-*s %*s ' "$label_max_width" "Keystrokes" "$value_width" "$keystrokes")"
            "$(printf ' %-*s %*s ' "$label_max_width" "Correct" "$value_width" "$correct")"
            "$(printf ' %-*s %*s ' "$label_max_width" "Incorrect" "$value_width" "$incorrect")"
            ""
          )
      done <<< "$entries"

      # Store the array in stats_lists
      stats_lists["$file_name"]="${stats_array[@]}"
    done

    _draw_table 50 "${stats_array[@]}"
  else
    echo "No stats available."
  fi
}
