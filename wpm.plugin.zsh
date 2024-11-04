# wpm plugin
#
# Typing speed test available within ZSH
#
# See the README for documentation.

# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

_omz_wpm_plugin_dir="${0:h}"

# Starts a typing speed test
#
# wpm_test <seconds>
#
function wpm_test() {
  local test_duration=${1:-60}  # Default to 60 if not provided

  zsh "$_omz_wpm_plugin_dir/wpm.zsh" "$_omz_wpm_plugin_dir" "$test_duration"
}