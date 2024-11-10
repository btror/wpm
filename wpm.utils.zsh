# Draw a table
_draw_table() {
    local width="$1"      # Table width
    local rows=("${@:2}") # Array of lines to draw: ""=empty row, "<char>"=separator, "<string>"=line of text
    local term_width=$(tput cols)
    local start_col=$(((term_width - width - 2) / 2))
    local table=""

    if [[ ${#funcstack[@]} -le 1 ]]; then
        echo "Warning: _draw_table should not be called directly from the terminal."
        return 1
    fi

    table+="\n$(printf '%*s' "$start_col" "")╔$(printf '═%.0s' $(seq 1 "$width"))╗\n"
    for line in "${rows[@]}"; do
        if [[ "$line" == "═" ]]; then
            table+="$(printf '%*s' "$start_col" "")╠$(printf $line'%.0s' $(seq 1 "$width"))╣\n"
        elif [[ "${#line}" -eq 1 ]]; then
            table+="$(printf '%*s' "$start_col" "")║$(printf $line'%.0s' $(seq 1 "$width"))║\n"
        else
            local clean_line=$(printf '%b' "$line" | sed 's/\x1b\[[0-9;]*m//g') # Remove ANSI codes for length
            local padding_left=$(((width - ${#clean_line}) / 2))
            local padding_right=$((width - ${#clean_line} - padding_left))
            line=$(echo "$line" | sed 's/%/%%/g') # Double any % symbols in line (% is a special character in printf)
            table+="$(printf '%*s' "$start_col" "")║$(printf '%*s' "$padding_left" "")$line$(printf '%*s' "$padding_right" "")║\n"
        fi
    done
    table+="$(printf '%*s' "$start_col" "")╚$(printf '═%.0s' $(seq 1 "$width"))╝\n"

    clear
    printf "$table"
}

# Load stats from the file
_load_stats() {
    local stats_file="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"

    if [[ ${#funcstack[@]} -le 1 ]]; then
        echo "Warning: _load_stats should not be called directly from the terminal."
        return 1
    fi

    if [[ -f "$stats_file" ]]; then
        jq '.' "$stats_file"
    else
        printf "{}"
    fi
}
