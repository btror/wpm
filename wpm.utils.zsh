### UI Functions ###

# Draw a table
_draw_table() {
    local width="$1"      # Table width
    local rows=("${@:2}") # Array of lines to draw: ""=empty row, "<char>"=separator, "<string>"=line of text
    local term_width=$(tput cols)
    local start_col=$(((term_width - width - 2) / 2))
    local table=""

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

# Draw file selection menu
_list_files() {
    local files=()
    local numbered_files=()
    local index=1
    local file

    for file in $(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/lists/*.txt; do
        files+=("$(basename "$file")")
        local filename="$(basename "$file")"
        numbered_files+=("$(printf "%-5s %*s" "$index." "$((FILE_SELECTION_TABLE_WIDTH - 10))" "$filename")")
        ((index++))
    done

    _draw_table "$FILE_SELECTION_TABLE_WIDTH" "Word Lists" "═" "${numbered_files[@]}"

    local selection
    while true; do
        local term_width=$(tput cols)
        local start_col=$(((term_width / 2) - (FILE_SELECTION_TABLE_WIDTH / 2) - 1))
        printf "\r\033[K"
        printf "\r$(printf '%*s' "$start_col" "")Select (1-${#files[@]}): "

        read selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#files[@]}" ]; then
            WORD_LIST_FILE_NAME="${files[$selection]}"
            break
        fi
        printf "%s\n" "Invalid selection. Please try again."
    done
}

### Stat Tracking Functions ###

# Load stats from the file
_load_stats() {
    local stats_file="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"
    if [[ -f "$stats_file" ]]; then
        cat "$stats_file"
    else
        printf "{}"
    fi
}

# Save stats to the file
_save_stats() {
    local data="$1"
    local stats_dir="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats"
    mkdir -p "$stats_dir"
    printf "%s" "$data" >"$stats_dir/stats.json"
}

### Word List Functions ###

# Generate random word from the list
_generate_random_word() {
    local random_index=$((($(od -An -N2 -i /dev/urandom) % (${#words[@]})) + 1))
    printf "%s\n" "${words[$random_index]}"
}

# Generate a list of random words
_generate_word_list() {
    local count="$1"
    local word_list=()
    for i in {1..$count}; do
        word_list+=("$(_generate_random_word)")
    done
    printf "%s\n" "${word_list[@]}"
}
