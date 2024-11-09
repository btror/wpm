# Trap to restore cursor visibility and exit cleanly on signals
trap 'tput cnorm; exit' INT TERM EXIT

# Enable certain options
setopt nullglob noglobdots

# Constants and Configurable Variables
_OMZ_WPM_PLUGIN_DIR=$1
TEST_DURATION=$2
TYPING_TABLE_WIDTH=100
RESULT_TABLE_WIDTH=50
FILE_SELECTION_TABLE_WIDTH=50
PROMPT_CHAR=">"
HEADER_SEPARATOR_CHAR="═"
DATA_SEPARATOR_CHAR="─"
VERTICAL_BORDER_CHAR="║"
WORD_LIST_FILE_NAME="words_top-250-english-easy.txt"

source "$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/wpm.utils.zsh"

### State Functions ###

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

### Main Function ###

main() {
    local start_time end_time elapsed_time correct_words incorrect_words total_keystrokes word_list
    local word_list_top word_list_bottom current_word_index user_input stats wpm accuracy selection

    # Ensure all necessary parameters are provided
    if [[ -z "$_OMZ_WPM_PLUGIN_DIR" || -z "$TEST_DURATION" ]]; then
        echo "Usage: $_OMZ_WPM_PLUGIN_DIR TEST_DURATION"
        exit 1
    fi

    trap 'update_state -1' WINCH # Handle window resize

    _list_files # Allow user to select word file

    start_time=$(date +%s)
    end_time=$((start_time + TEST_DURATION))

    correct_words=0
    incorrect_words=0
    total_keystrokes=0

    words=($(cat "$(dirname "$_OMZ_WPM_PLUGIN_DIR")/wpm/lists/$WORD_LIST_FILE_NAME"))
    word_list=($(_generate_word_list 20))
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

        total_keystrokes=$((total_keystrokes + 1)) # Increment for every keystroke

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
                word_list=("${word_list[@]:10}" $(_generate_word_list 10 | cut -d' ' -f1-10))
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

    # Save stats
    current_date=$(date +"%m/%d/%Y%l:%M%p")
    new_entry="{\"date\":\"$current_date\",\"wpm\":$wpm,\"test duration\":$TEST_DURATION,\"keystrokes\":$total_keystrokes,\"accuracy\":$accuracy,\"correct\":$correct_words,\"incorrect\":$incorrect_words}"

    # Update stats logic with jq
    stats=$(_load_stats)
    if command -v jq &>/dev/null; then
        if jq -e . >/dev/null 2>&1 <<<"$stats"; then
            if jq -e ".\"$WORD_LIST_FILE_NAME\"" >/dev/null 2>&1 <<<"$stats"; then
                stats=$(jq --arg file "$WORD_LIST_FILE_NAME" --argjson entry "$new_entry" '.[$file] = [$entry] + .[$file]' <<<"$stats")
            else
                stats=$(jq --arg file "$WORD_LIST_FILE_NAME" --argjson entry "$new_entry" '. + {($file): [$entry]}' <<<"$stats")
            fi
        else
            stats="{\"$WORD_LIST_FILE_NAME\": [$new_entry]}"
        fi
    else
        if [[ $stats == "{}" ]]; then
            stats="{\"$WORD_LIST_FILE_NAME\": [$new_entry]}"
        else
            stats="${stats/%\}/}],\"$WORD_LIST_FILE_NAME\": [$new_entry]}"
        fi
    fi

    _save_stats "$stats"

    local label_width=$(printf '%s\n' "Keystrokes" "Accuracy" "Correct" "Incorrect" | awk '{print length}' | sort -nr | head -n1)
    local value_width=10
    local label_max_width=$((RESULT_TABLE_WIDTH - value_width - 5))
    local result_data=(
        "$(printf ' %-*s %*s ' "$label_max_width" "Keystrokes" "$value_width" "$total_keystrokes")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Accuracy" "$value_width" "$accuracy%")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Correct" "$value_width" "$correct_words")"
        "$(printf ' %-*s %*s ' "$label_max_width" "Incorrect" "$value_width" "$incorrect_words")"
    )
    _draw_table "$RESULT_TABLE_WIDTH" "Result" "═" "" "$wpm WPM" "" "-" "${result_data[@]}"  "-" "" "═" "$WORD_LIST_FILE_NAME"
    
    tput cnorm # Show cursor again
}

main
