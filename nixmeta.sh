#!/bin/bash

# SPDX-FileCopyrightText: 2023 Technology Innovation Institute (TII)
#
# SPDX-License-Identifier: Apache-2.0

################################################################################

set -x # debug
set -e # exit immediately if a command fails
set -u # treat unset variables as an error and exit
set -o pipefail # exit if any pipeline command fails

################################################################################

# Script's directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Output file path
OUT_FILE="$SCRIPT_DIR/data/nixmeta.csv"
# Return values
TRUE=0; FALSE=1;

################################################################################

read_meta () {
    nixpkgs_path=$(nix-shell -p nix-info --run "nix-info -m" | grep "nixpkgs: " | cut -d'`' -f2)
    nix-env -qa --meta --json -f "$nixpkgs_path" '.*' >meta.json
    # Print the header line
    echo "\"pname\",\"version\",\"homepage\",\"spdxid\"" >"$OUT_FILE"
    # Query meta.json for the above mentioned fields
    jq -cr 'keys[] as $k | "\"\(.[$k] | .pname)\",\"\(.[$k] | .version)\",\"\(.[$k] | .meta | .homepage // "" )\",\"\(.[$k] | .meta | .license | if type == "array" then [.[].spdxId? // ""] else [.spdxId? // ""] end | join(";"))\""' meta.json | 
    sort | uniq >>"$OUT_FILE"

}

print_nix_info () {
    nix-shell -p nix-info --run "nix-info -m"
    echo "nixpkgs:"
    echo " - nixpkgs version: $(nix-instantiate --eval -E '(import <nixpkgs> {}).lib.version')"
}

################################################################################

exit_unless_command_exists () {
    if ! [ -x "$(command -v "$1")" ]; then
        err_print "command '$1' is not installed" >&2
        exit 1
    fi
}

err_print () {
    RED_BOLD='\033[1;31m'
    NC='\033[0m'
    # If stdout is to terminal print colorized error message, otherwise print
    # with no colors
    if [ -t 1 ]; then
        printf "${RED_BOLD}Error:${NC} %s\n" "$1" >&2
    else
        printf "Error: %s\n" "$1" >&2
    fi
}

on_exit () {
    if [ -d "$MYWORKDIR" ]; then
        # echo "See: $MYWORKDIR"
        rm -rf "$MYWORKDIR"
    fi
}

################################################################################

main () {
    exit_unless_command_exists "nix-env"
    exit_unless_command_exists "jq"
    exit_unless_command_exists "sort"
    exit_unless_command_exists "uniq"
    print_nix_info
    read_meta
    exit 0
}

################################################################################

exit_unless_command_exists "mktemp"
MYWORKDIR="$(mktemp -d)"
echo "[+] Using WORKDIR: '$MYWORKDIR'"
trap on_exit EXIT
cd "$MYWORKDIR"
main

################################################################################
