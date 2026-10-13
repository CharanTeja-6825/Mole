#!/usr/bin/env bats

load helpers/common

setup_file() { mole_test_setup_home uninstall-review; }
teardown_file() { mole_test_teardown_home; }

run_review_fixture() {
    run env HOME="$HOME/$1" PROJECT_ROOT="$PROJECT_ROOT" REVIEW_CHOICE="$1" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/ui/menu_paginated.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
cache="$HOME/Library/Caches/com.example.app"
data="$HOME/Library/Application Support/Example"
app="$HOME/Applications/Example.app"
mkdir -p "$cache" "$data" "$app"
encoded=$(printf '%s\n' "$cache" "$data" | base64 | tr -d '\n')
app_details=("Example|$app|com.example.app|12|$encoded||true|false|false|||||none||||")
running_apps=() sudo_apps=() brew_cask_apps=() leftover_notes=()
total_estimated_size=12
get_path_size_kb() { printf '10\n'; }
calculate_total_size() { if [[ -n "$1" ]]; then printf '1\n'; else printf '0\n'; fi; }
drain_pending_input() { :; }
paginated_multi_select() {
    [[ "$*" == *"Application Support/Example"* ]] || return 9
    [[ "${MOLE_PRESELECTED_INDICES:-}" == "" ]] || return 9
    MOLE_SELECTION_RESULT=""
    [[ "$REVIEW_CHOICE" != selected ]] || MOLE_SELECTION_RESULT=0
    return 0
}
if [[ "$REVIEW_CHOICE" == default ]]; then input=$'\n'; else input=$'d\n'; fi
MOLE_DRY_RUN=1 _batch_preview_and_confirm <<< "$input"
IFS='|' read -r _ _ _ _ result _ <<< "${app_details[0]}"
files=$(decode_file_list "$result" Example)
[[ "$files" == *"$cache"* ]] || exit 1
if [[ "$REVIEW_CHOICE" == selected ]]; then
    [[ "$files" == *"$data"* ]] || exit 1
else
    [[ "$files" != *"$data"* ]] || exit 1
fi
[[ -d "$cache" && -d "$data" && -d "$app" ]] || exit 1
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "uninstall preview keeps personal data by default without losing cache targets" { run_review_fixture default; }
@test "uninstall preview includes only explicitly selected personal data" { run_review_fixture selected; }
@test "uninstall personal-data selection can remain empty" { run_review_fixture empty; }

@test "configuration hints match removed paths and expose no configuration contents" {
    run env HOME="$HOME/config-references" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
mkdir -p "$HOME/.cursor" "$HOME/.config/paseo"
app="$HOME/Applications/Example.app"
removed="$HOME/.config/removed-tool"
# shellcheck disable=SC2016  # Literal forms stored by third-party installers.
printf '%s\n' 'alias example=Example' 'TOKEN=private-value' \
    "TOKEN=private-value command=\"$app/Contents/MacOS/example\"" \
    "command=\"${app}Helper/run\"" \
    'hook="$HOME/.config/removed-tool/run"' \
    'hook="${HOME}/.config/removed-tool/run"' \
    'hook="~/.config/removed-tool/run"' > "$HOME/.zshrc"
printf '{"command":"%s/Contents/MacOS/example"}\n' "$app" > "$HOME/.cursor/mcp.json"
cp "$HOME/.zshrc" "$HOME/config-before"
uninstall_configuration_references "$app" "$removed" "$HOME/.config/paseo"
cmp "$HOME/.zshrc" "$HOME/config-before" || exit 1
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"~/.zshrc:3"* && "$output" == *"~/.zshrc:5"* && "$output" == *"~/.zshrc:6"* && "$output" == *"~/.zshrc:7"* ]] || return 1
    [[ "$output" == *"~/.cursor/mcp.json:1"* ]] || return 1
    [[ "$output" != *"private-value"* && "$output" != *"~/.zshrc:4"* && "$output" != *"~/.zshrc:1"* ]] || return 1
}

@test "configuration hints keep live owners and skip links binary and oversized files" {
    run env HOME="$HOME/config-protection" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
mkdir -p "$HOME/Applications/Live.app" "$HOME/outside" "$HOME/.cursor"
app="$HOME/Applications/Gone.app"
printf '%s\n' "$app/run" > "$HOME/outside/settings"
ln -s "$HOME/outside/settings" "$HOME/.zshrc"
printf '%s\0' "$app/run" > "$HOME/.bashrc"
/usr/bin/perl -e 'print "x" x 1048577' > "$HOME/.profile"
printf '%s\n' "$app/run" >> "$HOME/.profile"
printf '%s\n' "$HOME/Applications/Live.app/run" > "$HOME/.cursor/mcp.json"
uninstall_configuration_references "$app" "$HOME/Applications/Live.app"
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" != *"Configuration references"* ]] || return 1
}

@test "configuration hint failures discard partial output and signals propagate" {
    run env HOME="$HOME/config-timeout" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
run_with_timeout() { cat > /dev/null; printf 'PARTIAL_SECRET\n'; return 124; }
uninstall_configuration_references /Applications/Gone.app
run_with_timeout() { cat > /dev/null; return 130; }
rc=0
uninstall_configuration_references /Applications/Gone.app || rc=$?
[[ $rc -eq 130 ]] || exit 1
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" != *"PARTIAL_SECRET"* ]] || return 1
}

@test "uninstall keeps unselected preferences at every post-removal side effect" {
    run env HOME="$HOME/keep-preferences" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
source "$PROJECT_ROOT/tests/helpers/uninstall.bash"
mole_test_isolate_uninstall_inventory
app="$HOME/Applications/Example.app"
preferences="$HOME/Library/Preferences/com.example.app.plist"
byhost="$HOME/Library/Preferences/ByHost/com.example.app.fixture.plist"
mkdir -p "$app" "$(dirname "$byhost")"
printf 'settings\n' > "$preferences"
printf 'settings\n' > "$byhost"
brew() { return 1; }
get_brew_cask_name() { return 1; }
pgrep() { return 1; }
pkill() { return 0; }
remove_apps_from_dock() { :; }
refresh_launch_services_after_uninstall() { :; }
defaults() { printf 'DEFAULTS:%s\n' "$*" >> "$HOME/forbidden"; return 0; }
mole_delete() {
    if [[ "$1" == "$app" ]]; then
        mv "$app" "$HOME/removed-app"
    else
        printf '%s\n' "$1" >> "$HOME/forbidden"
    fi
}
selected_apps=("0|$app|Example|com.example.app|0|Never")
files_cleaned=0 total_items=0 total_size_cleaned=0
batch_uninstall_applications <<< ''
[[ ! -e "$app" && -f "$preferences" && -f "$byhost" ]] || exit 1
[[ ! -e "$HOME/forbidden" ]] || { cat "$HOME/forbidden"; exit 1; }
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "personal-data menu keeps empty Enter while app selection keeps its existing default" {
    run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/ui/menu_paginated.sh"
enter_alt_screen() { :; }
leave_alt_screen() { :; }
stty() { :; }
tput() { :; }
clear() { :; }
printf_at() { :; }
export MOLE_MANAGED_ALT_SCREEN=1
read_key() { printf 'ENTER\n'; }
MOLE_PRESELECTED_INDICES=""
_MOLE_MENU_KEEP_EMPTY=true
paginated_multi_select "Data" alpha beta <<< '' > /dev/null || exit $?
[[ -z "$MOLE_SELECTION_RESULT" ]] || exit 1
unset _MOLE_MENU_KEEP_EMPTY
paginated_multi_select "Apps" alpha beta <<< '' > /dev/null || exit $?
[[ "$MOLE_SELECTION_RESULT" == 0 ]] || exit 1
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "configuration hints only inspect absent paths from successful non-dry removals" {
    run env HOME="$HOME/config-batch" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'SH'
set -euo pipefail
source "$PROJECT_ROOT/lib/uninstall/batch.sh"
mkdir -p "$HOME/kept" "$HOME/returned.app"
success_items=("$HOME/gone.app" "$HOME/returned.app")
encoded=$(printf '%s\n' "$HOME/kept" "$HOME/gone-data" | base64 | tr -d '\n')
failed=$(printf '%s' "$HOME/failed-data" | base64 | tr -d '\n')
app_details=("Gone|$HOME/gone.app|com.example.gone|0|$encoded|" "Failed|$HOME/failed.app|com.example.failed|0|$failed|")
uninstall_configuration_references() { printf '%s\n' "$@"; }
output=$(_batch_report_configuration_references)
[[ "$output" == *"$HOME/gone-data"* && "$output" != *"$HOME/failed"* && "$output" != *"$HOME/kept"* ]] || exit 1
output=$(MOLE_DRY_RUN=1 _batch_report_configuration_references)
[[ -z "$output" ]] || exit 1
SH
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "uninstall data review handles real terminal selection empty save and cancel" {
    run python3 "$PROJECT_ROOT/tests/uninstall_review_pty.py"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
