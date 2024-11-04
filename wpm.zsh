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

# Table drawing functions
draw_top_border() {
    local width="$1"
    printf "╔%*s╗\n" "$width" | sed 's/ /═/g'
}

draw_bottom_border() {
    local width="$1"
    printf "╚%*s╝\n" "$width" | sed 's/ /═/g'
}

draw_separator() {
    local width="$1"
    local separator_char="${2:-─}" # default is '─'
    local vertical_border_char="${3:-}" # default is empty

    if [[ "$separator_char" == "═" ]]; then
        printf "╠%*s╣\n" "$width" | sed "s/ /$separator_char/g"
    else
        printf "$vertical_border_char%*s$vertical_border_char\n" "$width" | sed "s/ /$separator_char/g"
    fi
}

draw_new_line() {
    local width="$1"
    local label="${2:-}" # default is empty
    local value="${3:-}" # default is empty
    local align="${4:-}" # center, left, or right
    local border_char="${5:-}" # default is empty

    if [[ "$align" == "center" ]]; then
        center_align "$width" "$label" "$border_char"
    elif [[ "$align" == "right" ]]; then
        right_align "$width" "$label" "$value" "$border_char"
    else
        left_align "$width" "$label" "$value" "$border_char"
    fi
}

center_align() {
    local width="$1"
    local label="$2"
    local border_char="$3"
    local clean_label=$(printf '%b' "$label" | sed 's/\x1b\[[0-9;]*m//g')
    local padding_left=$(( (width - ${#clean_label}) / 2 ))
    local padding_right=$(( width - ${#clean_label} - padding_left ))
    printf "$border_char%${padding_left}s%s%${padding_right}s$border_char\n" "" "$label" ""
}

left_align() {
    local width="$1"
    local label="$2"
    local value="$3"
    local border_char="$4"
    local clean_label=$(printf '%b' "$label" | sed 's/\x1b\[[0-9;]*m//g')
    printf "$border_char  %-10s %-*s  $border_char\n" "$clean_label" $((width - 15)) "$value"
}

right_align() {
    local width="$1"
    local label="$2"
    local value="$3"
    local border_char="$4"
    local clean_label=$(printf '%b' "$label" | sed 's/\x1b\[[0-9;]*m//g')
    printf "$border_char  %-10s %$((width - 15))s  $border_char\n" "$clean_label" "$value"
}

# File selection menu
select_word_list() {
    local files=()
    for file in "$(dirname "$_omz_wpm_plugin_dir")/wpm/lists"/*.txt; do
        files+=($(basename "$file"))
    done

    draw_top_border "$file_selection_table_width"
    draw_new_line "$file_selection_table_width" "Word Lists" "" "center" "$vertical_border_char"
    draw_separator "$file_selection_table_width" "$header_separator_char" "$vertical_border_char"
    for i in {1..${#files[@]}}; do
        draw_new_line "$file_selection_table_width" "$i." "${files[$i]}" "right" "$vertical_border_char"
    done
    draw_bottom_border "$file_selection_table_width"

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

select_word_list

# Typing test functions
generate_random_word() {
    local random_index=$(( ( $(od -An -N2 -i /dev/urandom) % (${#words[@]}) ) + 1 ))
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

display_state() {
    local is_correct="$1"
    clear

    if [[ -n $is_correct && $current_word_index -gt 1 ]]; then
        index=$((current_word_index - 1))
        word_list_top[$index]=$(printf "%s" "${word_list_top[index]}" | sed 's/\x1b\[[0-9;]*m//g')

        if [[ $is_correct -eq 0 ]]; then
            word_list_top[$index]=$'\e[32m'"${word_list_top[index]}"$'\e[0m'
        elif [[ $is_correct -eq 1 ]]; then
            word_list_top[$index]=$'\e[31m'"${word_list_top[index]}"$'\e[0m'
        fi
    fi

    word_list_top[$current_word_index]=$'\e[47;40m'"${word_list_top[current_word_index]}"$'\e[0m'

    draw_separator "$typing_table_width" "" ""
    draw_new_line "$typing_table_width" "$word_list_top" "" "center" ""
    draw_new_line "$typing_table_width" "$word_list_bottom" "" "center" ""
    draw_separator "$typing_table_width" "" ""

    printf "$prompt_char $user_input"
}

start_time=$(date +%s)
end_time=$(( start_time + test_duration ))
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

display_state

# Main loop
while [ $(date +%s) -lt $end_time ]; do
    remaining_time=$(( end_time - $(date +%s) ))
    read -t $remaining_time -k 1 char || break

    total_keystrokes=$((total_keystrokes + 1)) # Increment for every keystroke

    if [[ "$char" == $'\177' ]]; then  # backspace keystroke
        user_input=${user_input%?}  # remove last character
        display_state
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
        display_state $is_correct
    else
        user_input+=$char
        display_state
    fi
done

elapsed_time=$(( end_time - start_time ))
total_words=$(( correct_words + incorrect_words ))
wpm=$(( (correct_words * 60) / elapsed_time ))
accuracy=0
if [[ $total_words -gt 0 ]]; then
    accuracy=$(( (correct_words * 100) / total_words ))
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
    printf "%s" "$data" > "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats/stats.json"
}

if ! command -v jq &> /dev/null; then # Check if jq is available
    printf "Warning: jq not found. Please install jq for better JSON handling.\n"
    printf "Installing jq is recommended: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)\n"
    sleep 2
fi

current_date=$(date +"%m/%d/%Y %l:%M%p")
new_entry="{\"date\":\"$current_date\",\"wpm\":$wpm,\"test duration\":$test_duration,\"wpm\":$wpm,\"keystrokes\":$total_keystrokes,\"accuracy\":$accuracy,\"correct\":$correct_words,\"incorrect\":$incorrect_words}"
mkdir -p "$(dirname "$_omz_wpm_plugin_dir")/wpm/stats"
stats=$(load_stats)

if command -v jq &> /dev/null; then
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

# Test run result table
printf "\n"
clear 

draw_top_border "$result_table_width"
draw_new_line "$result_table_width" "Result" "" "center" "$vertical_border_char"
draw_separator "$result_table_width" "$header_separator_char" "$vertical_border_char"
draw_new_line "$result_table_width" "" "" "" "$vertical_border_char"
draw_new_line "$result_table_width" "$wpm WPM" "" "center" "$vertical_border_char"
draw_new_line "$result_table_width" "" "" "" "$vertical_border_char"
draw_separator "$result_table_width" "$data_separator_char" "$vertical_border_char"
draw_new_line "$result_table_width" "Keystrokes" "$total_keystrokes" "right" "$vertical_border_char"
draw_new_line "$result_table_width" "Accuracy" "$accuracy%" "right" "$vertical_border_char"
draw_new_line "$result_table_width" "Correct" "$correct_words" "right" "$vertical_border_char"
draw_new_line "$result_table_width" "Incorrect" "$incorrect_words" "right" "$vertical_border_char"
draw_separator "$result_table_width" "$data_separator_char" "$vertical_border_char"
draw_new_line "$result_table_width" "$word_list_file_name" "" "center" "$vertical_border_char"
draw_bottom_border "$result_table_width"