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

TYPING_TABLE_WIDTH=100
RESULT_TABLE_WIDTH=50
FILE_SELECTION_TABLE_WIDTH=50
PROMPT_CHAR=">"
HEADER_SEPARATOR_CHAR="═"
DATA_SEPARATOR_CHAR="─"
VERTICAL_BORDER_CHAR="║"
WORD_LIST_FILE_NAME="words_top-250-english-easy.txt"

source "$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/wpm.utils.zsh"

# Starts a typing speed test
#
# wpm_test <seconds>
#
function wpm_test() {
    local test_duration=${1:-60}  # Default to 60 if not provided
    local start_time end_time elapsed_time correct_words incorrect_words keystrokes word_list
    local word_list_top word_list_bottom current_word_index user_input stats wpm accuracy selection

    # Ensure all necessary parameters are provided
    if [[ -z "$_OMZ_WPM_PLUGIN_DIR" || -z "$test_duration" ]]; then
        echo "Usage: $_OMZ_WPM_PLUGIN_DIR test_duration"
        exit 1
    fi

    # Update UI state
    update_state() {
        local is_correct="$1"

        # Handle word status and re-draw the table
        if [[ $is_correct -eq -1 ]]; then
            _draw_table "$TYPING_TABLE_WIDTH" "$word_list_top" "$word_list_bottom"
        elif [[ -n $is_correct && $current_word_index -eq 1 ]]; then
            word_list_top[$current_word_index]=$'\e[47;40m'"${word_list_top[current_word_index]}"$'\e[0m'
            _draw_table "$TYPING_TABLE_WIDTH" "$word_list_top" "$word_list_bottom"
        elif [[ -n $is_correct && $current_word_index -gt 1 ]]; then
            index=$((current_word_index - 1))
            word_list_top[$index]=$(printf "%s" "${word_list_top[index]}" | sed 's/\x1b\[[0-9;]*m//g')

            if [[ $is_correct -eq 0 ]]; then
                word_list_top[$index]=$'\e[32m'"${word_list_top[index]}"$'\e[0m'
            elif [[ $is_correct -eq 1 ]]; then
                word_list_top[$index]=$'\e[31m'"${word_list_top[index]}"$'\e[0m'
            fi

            word_list_top[$current_word_index]=$'\e[47;40m'"${word_list_top[current_word_index]}"$'\e[0m'
            _draw_table "$TYPING_TABLE_WIDTH" "$word_list_top" "$word_list_bottom"
        fi

        local term_width=$(tput cols)
        local start_col=$(((term_width / 2) - (TYPING_TABLE_WIDTH / 2) - 1))
        printf "\r\033[K"
        printf "\r$(printf '%*s' "$start_col" "")$PROMPT_CHAR $user_input"
    }

    # Generate random word from the list
    generate_random_word() {
        local random_index=$((($(od -An -N2 -i /dev/urandom) % (${#words[@]})) + 1))
        printf "%s\n" "${words[$random_index]}"
    }

    # Generate a list of random words
    generate_word_list() {
        local count="$1"
        local word_list=()
        for i in {1..$count}; do
            word_list+=("$(generate_random_word)")
        done
        printf "%s\n" "${word_list[@]}"
    }

    # Draw file selection menu
    list_files() {
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

    trap 'update_state -1' WINCH # Handle window resize

    list_files # Allow user to select word file

    start_time=$(date +%s)
    end_time=$((start_time + test_duration))

    correct_words=0
    incorrect_words=0
    keystrokes=0

    words=($(cat "$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/lists/$WORD_LIST_FILE_NAME"))
    word_list=($(generate_word_list 20))
    word_list_top=("${word_list[@]:0:10}")
    word_list_bottom=("${word_list[@]:10}")

    current_word_index=1

    user_input=""

    tput civis # Hide cursor
    update_state 0

    # Main loop
    while [[ $(date +%s) -lt $end_time ]]; do
        remaining_time=$((end_time - $(date +%s)))
        read -t $remaining_time -k 1 char || break

        keystrokes=$((keystrokes + 1)) # Increment for every keystroke

        if [[ "$char" == $'\177' ]]; then # Backspace
            user_input=${user_input%?}
            update_state
        elif [[ "$char" == $'\040' ]]; then # Spacebar
            is_correct=1
            if [[ "$user_input" == "${word_list[$current_word_index]}" ]]; then
                correct_words=$((correct_words + 1))
                is_correct=0
            else
                incorrect_words=$((incorrect_words + 1))
            fi

            if [[ $current_word_index -ge 10 ]]; then
                word_list=("${word_list[@]:10}" $(generate_word_list 10 | cut -d' ' -f1-10))
                word_list_top=("${word_list[@]:0:10}")
                word_list_bottom=("${word_list[@]:10}")
                current_word_index=0
            fi
            current_word_index=$((current_word_index + 1))
            user_input=""
            update_state $is_correct
        else
            user_input+=$char
            update_state
        fi
    done

    # Calculate stats
    elapsed_time=$((end_time - start_time))
    total_words=$((correct_words + incorrect_words))
    wpm=$(((correct_words * 60) / elapsed_time))
    accuracy=$((correct_words * 100 / total_words))

    current_date=$(date +"%m/%d/%Y%l:%M%p")
    new_entry="{\"date\":\"$current_date\",\"wpm\":$wpm,\"test duration\":$test_duration,\"keystrokes\":$keystrokes,\"accuracy\":$accuracy,\"correct\":$correct_words,\"incorrect\":$incorrect_words}"

    # Update stats logic with jq
    stats=$(_load_history)
    if command -v jq &>/dev/null; then
        if jq -e . >/dev/null 2>&1 <<<"$stats"; then
            # Check if the specified file already exists in the stats data
            if jq -e ".\"$WORD_LIST_FILE_NAME\"" >/dev/null 2>&1 <<<"$stats"; then
                stats=$(jq --arg file "$WORD_LIST_FILE_NAME" --argjson entry "$new_entry" --argjson new_wpm "$wpm" --argjson new_accuracy "$accuracy" '
                    .[$file] |= (
                        .average.["tests taken"] += 1 |
                        .average.wpm = ((.average.wpm * (.average.["tests taken"] - 1) + $new_wpm) / .average.["tests taken"]) |
                        .average.accuracy = ((.average.accuracy * (.average.["tests taken"] - 1) + $new_accuracy) / .average.["tests taken"]) |
                        .results += [$entry]
                    )
                ' <<<"$stats")
            else
                # If the file is new, add it without altering existing data
                stats=$(jq --arg file "$WORD_LIST_FILE_NAME" --argjson entry "$new_entry" --argjson new_wpm "$wpm" --argjson new_accuracy "$accuracy" '
                    . + {($file): {average: {wpm: $new_wpm, accuracy: $new_accuracy, "tests taken": 1}, results: [$entry]}}
                ' <<<"$stats")
            fi
        else
            # Initialize stats with the first entry if stats file was empty or invalid
            stats="{\"$WORD_LIST_FILE_NAME\": {\"average\": {\"wpm\": $wpm, \"accuracy\": $accuracy, \"tests taken\": 1}, \"results\": [$new_entry]}}"
        fi
    else
        # Non-jq fallback (simple string concatenation, if jq isn't available)
        if [[ $stats == "{}" ]]; then
            stats="{\"$WORD_LIST_FILE_NAME\": {\"average\": {\"wpm\": $wpm, \"accuracy\": $accuracy, \"tests taken\": 1}, \"results\": [$new_entry]}}"
        else
            stats="${stats/%\}/},\"$WORD_LIST_FILE_NAME\": {\"average\": {\"wpm\": $wpm, \"accuracy\": $accuracy, \"tests taken\": 1}, \"results\": [$new_entry]}}"
        fi
    fi

    # Save stats
    mkdir -p "$stats_dir"
    printf "%s" "$stats" >"$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"

    local label_width=$(printf '%s\n' "Keystrokes" "Accuracy" "Correct" "Incorrect" | awk '{print length}' | sort -nr | head -n1)
    local value_width=10
    local label_max_width=$((RESULT_TABLE_WIDTH - value_width - 5))
    local result_data=(
        "$(printf ' %-*s %*s ' "$label_max_width" "Keystrokes" "$value_width" "$keystrokes")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Accuracy" "$value_width" "$accuracy%")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Correct" "$value_width" "$correct_words")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Incorrect" "$value_width" "$incorrect_words")"
    )
    _draw_table "$RESULT_TABLE_WIDTH" "Result" "═" "" "$wpm WPM" "" "-" "${result_data[@]}"  "-" "" "═" "$WORD_LIST_FILE_NAME"
    
    tput cnorm # Show cursor again
}

# Shows typing speed test history
#
# wpm_history
#
function wpm_history() {
    local stats_file="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"

    if [[ -f "$stats_file" ]]; then
        local stats=$(_load_history)
        local value_width=20
        local result_table_width=40
        local label_max_width=$((result_table_width - value_width - 5))
        local stats_array=("History" "═" "")
        declare -A stats_lists

        for file_name in $(echo "$stats" | jq -r 'keys[]'); do
            stats_array+=("-" "$(printf "$file_name")" "-")
            entries=$(echo "$stats" | jq -c ".\"$file_name\".results[]")

            # Process each entry in the results array for the current file
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
        echo "No history available."
    fi
}

# Shows average results for each word list
#
# wpm_stats
#
function wpm_stats() {
    local stats_file="$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/stats/stats.json"

    if [[ -f "$stats_file" ]]; then
        local stats=$(_load_stats)
        local value_width=20
        local result_table_width=50
        local label_max_width=$((result_table_width - value_width - 5))
        local stats_array=("Speed Stats" "═" "")
        declare -A stats_lists

        for file_name in $(echo "$stats" | jq -r 'keys[]'); do
            # Print file name as a header
            stats_array+=("-" "$(printf "$file_name")" "-")

            # Extract stats for the current file
            average_data=$(echo "$stats" | jq -c ".\"$file_name\"")
            wpm=$(echo "$average_data" | jq -r '.wpm')
            accuracy=$(echo "$average_data" | jq -r '.accuracy')
            tests_taken=$(echo "$average_data" | jq -r '.["tests taken"]')

            # Add data to stats_array
            stats_array+=(
                "$(printf ' %-*s %*s ' "$label_max_width" "Average WPM" "$value_width" "$wpm WPM")"
                "$(printf ' %-*s %*s ' "$label_max_width" "Average Accuracy" "$value_width" "$accuracy%")"
                "$(printf ' %-*s %*s ' "$label_max_width" "Tests Taken" "$value_width" "$tests_taken")"
                ""
            )

            # Store the array in stats_lists
            stats_lists["$file_name"]="${stats_array[@]}"
        done

        _draw_table "$result_table_width" "${stats_array[@]}"
    else
        echo "No stats available."
    fi
}
