trap 'tput cnorm; exit' INT TERM EXIT # Enable cursor and exit on interrupt
setopt nullglob noglobdots

# Configurable variables
typing_table_width=100
result_table_width=42
file_selection_table_width=45
prompt_char=">"
header_separator_char="═"
data_separator_char="─"
vertical_border_char="║"
_omz_wpm_plugin_dir=$1
test_duration=$2
word_list_file_name="words_top-250-english-easy.txt"

draw_table() {
    local width="$1"      # Table width
    local rows=("${@:2}") # Array of lines to draw: ""=empty row, "<char>"=separator, "<string>"=line of text
    local table=""

    table+="\n╔$(printf '═%.0s' $(seq 1 "$width"))╗\n"
    for line in "${rows[@]}"; do
        if [[ "$line" == "═" ]]; then
            table+="╠$(printf $line'%.0s' $(seq 1 "$width"))╣\n"
        elif [[ "${#line}" -eq 1 ]]; then
            table+="║$(printf $line'%.0s' $(seq 1 "$width"))║\n"
        else
            local clean_line=$(printf '%b' "$line" | sed 's/\x1b\[[0-9;]*m//g') # Remove ANSI codes for length
            local padding_left=$(((width - ${#clean_line}) / 2))
            local padding_right=$((width - ${#clean_line} - padding_left))
            line=$(echo "$line" | sed 's/%/%%/g') # Double any % symbols in line (% is a special character in printf)
            table+="║$(printf '%*s' "$padding_left" "")$line$(printf '%*s' "$padding_right" "")║\n"
        fi
    done
    table+="╚$(printf '═%.0s' $(seq 1 "$width"))╝\n"

    clear
    printf "$table"
}

list_files() {
    local files=()
    local numbered_files=()
    local index=1

    for file in $(dirname "$_omz_wpm_plugin_dir")/wpm/lists/*.txt; do
        files+=("$(basename "$file")")
        numbered_files+="$index. $(basename "$file")\n"
        index=$((index + 1))
    done

    draw_table "$file_selection_table_width" "Word Lists" "═" "${numbered_files[@]}"

    local selection
    while true; do
        printf "Select (1-${#files[@]}): "
        read selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#files[@]}" ]; then
            word_list_file_name="${files[$selection]}"
            break
        fi
        printf "%s\n" "Invalid selection. Please try again."
    done
}

list_files

generate_random_word() {
    local random_index=$((($(od -An -N2 -i /dev/urandom) % (${#words[@]})) + 1))
    printf "%s\n" "${words[$random_index]}"
}

generate_word_list() {
    local count="$1"
    local word_list=()
    for i in {1..$count}; do
        word_list+=("$(generate_random_word)")
    done
    printf "%s\n" "${word_list[@]}"
}

show_state() {
    local is_correct="${1}"

    if [[ -n $is_correct && $current_word_index -eq 1 ]]; then
        word_list_top[$current_word_index]=$'\e[47;40m'"${word_list_top[current_word_index]}"$'\e[0m'
        draw_table "$typing_table_width" "$word_list_top" "$word_list_bottom"
    elif [[ -n $is_correct && $current_word_index -gt 1 ]]; then
        index=$((current_word_index - 1))
        word_list_top[$index]=$(printf "%s" "${word_list_top[index]}" | sed 's/\x1b\[[0-9;]*m//g')

        if [[ $is_correct -eq 0 ]]; then
            word_list_top[$index]=$'\e[32m'"${word_list_top[index]}"$'\e[0m'
        elif [[ $is_correct -eq 1 ]]; then
            word_list_top[$index]=$'\e[31m'"${word_list_top[index]}"$'\e[0m'
        fi

        word_list_top[$current_word_index]=$'\e[47;40m'"${word_list_top[current_word_index]}"$'\e[0m'
        draw_table "$typing_table_width" "$word_list_top" "$word_list_bottom"
    fi

    printf "\r\033[K"
    printf "$prompt_char $user_input"
}

# TODO: wrap other logic in functions
start_time=$(date +%s)
end_time=$((start_time + test_duration))
words=($(cat "$(dirname "$_omz_wpm_plugin_dir")/wpm/lists/$word_list_file_name"))
word_list=($(generate_word_list 20))
word_list_top=("${word_list[@]:0:10}")
word_list_bottom=("${word_list[@]:10}")
current_word_index=1
user_input=""
correct_words=0
incorrect_words=0
total_keystrokes=0

tput civis # Hide cursor

show_state 0

# Main loop
while [ $(date +%s) -lt $end_time ]; do
    remaining_time=$((end_time - $(date +%s)))

    read -t $remaining_time -k 1 char || break

    total_keystrokes=$((total_keystrokes + 1)) # Increment for every keystroke

    if [[ "$char" == $'\177' ]]; then # backspace keystroke
        user_input=${user_input%?}    # remove last character
        show_state
    elif [[ "$char" == " " ]]; then # space keystroke
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
        show_state $is_correct
    else
        user_input+=$char
        show_state
    fi
done

elapsed_time=$((end_time - start_time))
total_words=$((correct_words + incorrect_words))
wpm=$(((correct_words * 60) / elapsed_time))
accuracy=0
if [[ $total_words -gt 0 ]]; then
    accuracy=$(((correct_words * 100) / total_words))
fi

# Store test results
load_stats() {
    if [ -f "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats/stats.json" ]; then
        cat "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats/stats.json"
    else
        printf "{}"
    fi
}

save_stats() {
    local data="$1"
    mkdir -p "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats"
    printf "%s" "$data" >"$(dirname "$_omz_wpm_plugin_dir")/wpm/stats/stats.json"
}

if ! command -v jq &>/dev/null; then # Check if jq is available
    printf "Warning: jq not found. Please install jq for better JSON handling.\n"
    printf "Installing jq is recommended: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)\n"
    sleep 2
fi

current_date=$(date +"%m/%d/%Y%l:%M%p")
new_entry="{\"date\":\"$current_date\",\"wpm\":$wpm,\"test duration\":$test_duration,\"wpm\":$wpm,\"keystrokes\":$total_keystrokes,\"accuracy\":$accuracy,\"correct\":$correct_words,\"incorrect\":$incorrect_words}"
mkdir -p "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats"
stats=$(load_stats)

if command -v jq &>/dev/null; then
    if jq -e . >/dev/null 2>&1 <<<"$stats"; then
        if jq -e ".\"$word_list_file_name\"" >/dev/null 2>&1 <<<"$stats"; then
            stats=$(jq --arg file "$word_list_file_name" --argjson entry "$new_entry" \
                '.[$file] = [$entry] + .[$file]' <<<"$stats")
        else
            stats=$(jq --arg file "$word_list_file_name" --argjson entry "$new_entry" \
                '. + {($file): [$entry]}' <<<"$stats")
        fi
    else
        stats="{\"$word_list_file_name\": [$new_entry]}"
    fi
else
    if [[ $stats == "{}" ]]; then
        stats="{\"$word_list_file_name\": [$new_entry]}"
    else
        stats=${stats%?}
        if [[ $stats == *"\"$word_list_file_name\""* ]]; then
            stats=$(printf "%s" "$stats" | sed "s/\"$word_list_file_name\":\[/\"$word_list_file_name\":[$new_entry,/")
        else
            stats="$stats,\"$word_list_file_name\":[$new_entry]}"
        fi
    fi
fi

save_stats "$stats"
clear

draw_table "$result_table_width" "Result" "═" "" "$wpm WPM" "" "-" "Keystrokes $total_keystrokes" "Accuracy $accuracy%" "Correct $correct_words" "Incorrect $incorrect_words" "-" "" "═" "$word_list_file_name"
