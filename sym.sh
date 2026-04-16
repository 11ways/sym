#!/usr/bin/env bash

# sym - Symbolic Link Manager
# Version: 1.1.0
# Author: Roel Van Gils
# License: MIT
# Description: A simple, user-friendly tool for managing symbolic links in ~/.local/bin

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# === METADATA ===
readonly VERSION="1.1.0"
readonly SCRIPT_NAME="sym"

# === CONFIGURATION ===
# The directory where symbolic links will be created.
readonly DEST_DIR="${SYM_DIR:-$HOME/.local/bin}"

# State directory for undo journal and snapshots.
readonly STATE_DIR="${SYM_STATE_DIR:-$HOME/.local/share/sym}"
readonly LAST_OP_FILE="$STATE_DIR/last_op.json"
readonly SNAPSHOT_DIR="$STATE_DIR/snapshots"

# Global flags
FORCE_MODE=false
DRY_RUN_MODE=false
OUTPUT_FORMAT="text"  # text, json, csv

# === COLOR SETUP ===
# Check if colors should be enabled
setup_colors() {
    # Disable colors if NO_COLOR is set, output is not a terminal, or TERM is dumb
    if [[ -n "${NO_COLOR+x}" ]] || [[ ! -t 1 ]] || [[ "${TERM:-}" == "dumb" ]]; then
        C_RED=""
        C_GREEN=""
        C_YELLOW=""
        C_BLUE=""
        C_WHITE=""
        C_GRAY=""
        C_RESET=""
        C_BOLD=""
    else
        C_RED='\033[0;31m'
        C_GREEN='\033[0;32m'
        C_YELLOW='\033[0;33m'
        C_BLUE='\033[0;34m'
        C_WHITE='\033[1;37m'
        C_GRAY='\033[1;30m'
        C_RESET='\033[0m'
        C_BOLD='\033[1m'
    fi
}

# === UTILITY FUNCTIONS ===

# Prints an error message and exits
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    echo -e "${C_RED}Error:${C_RESET} $message" >&2
    exit "$exit_code"
}

# Prints a warning message
warn() {
    local message="$1"
    echo -e "${C_YELLOW}Warning:${C_RESET} $message" >&2
}

# Prints a success message
success() {
    local message="$1"
    echo -e "${C_GREEN}✓${C_RESET} $message"
}

# Prints an info message
info() {
    local message="$1"
    echo -e "${C_BLUE}ℹ${C_RESET} $message"
}

# Validates a link name
validate_link_name() {
    local name="$1"

    # Check if empty
    if [[ -z "$name" ]]; then
        error_exit "Link name cannot be empty."
    fi

    # Check for path separators
    if [[ "$name" == */* ]]; then
        error_exit "Link name cannot contain path separators (/)."
    fi

    # Check for dangerous patterns
    if [[ "$name" == "." || "$name" == ".." ]]; then
        error_exit "Link name cannot be '.' or '..'."
    fi

    # Check for hidden files (starting with .)
    if [[ "$name" == .* ]]; then
        warn "Link name starts with '.', making it hidden."
    fi

    # Check for special characters that might cause issues
    if [[ "$name" =~ [[:space:]] ]]; then
        warn "Link name contains spaces, which may cause issues."
    fi

    return 0
}

# Gets file/directory creation date (cross-platform)
get_creation_date() {
    local file="$1"
    local date=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "")
    else
        # Linux
        date=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 || echo "")
    fi

    echo "$date"
}

# Gets file size in human-readable format (cross-platform)
get_file_size() {
    local file="$1"
    local size_bytes=""

    # Only process regular files
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        size_bytes=$(stat -f "%z" "$file" 2>/dev/null || echo "")
    else
        # Linux
        size_bytes=$(stat -c "%s" "$file" 2>/dev/null || echo "")
    fi

    if [[ -z "$size_bytes" ]]; then
        echo ""
        return
    fi

    # Convert to human-readable format with decimals
    if command -v numfmt &> /dev/null; then
        # Use numfmt if available (better formatting)
        numfmt --to=iec-i --suffix=B --format="%.1f" "$size_bytes" 2>/dev/null || echo "${size_bytes}B"
    else
        # Fallback to manual conversion
        if (( size_bytes < 1024 )); then
            echo "${size_bytes}B"
        elif (( size_bytes < 1048576 )); then
            echo "$(awk "BEGIN {printf \"%.1f\", $size_bytes/1024}")KB"
        elif (( size_bytes < 1073741824 )); then
            echo "$(awk "BEGIN {printf \"%.1f\", $size_bytes/1048576}")MB"
        else
            echo "$(awk "BEGIN {printf \"%.1f\", $size_bytes/1073741824}")GB"
        fi
    fi
}

# Gets the type of a path (file, directory, broken symlink, etc.)
get_path_type() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        if [[ -L "$path" ]]; then
            echo "broken-symlink"
        else
            echo "not-found"
        fi
    elif [[ -d "$path" ]]; then
        echo "directory"
    elif [[ -f "$path" ]]; then
        echo "file"
    else
        echo "other"
    fi
}

# Strips common file extensions from a name
strip_extensions() {
    local name="$1"
    # Remove common script/binary extensions
    echo "$name" | sed -E 's/\.(sh|bash|zsh|py|rb|js|pl|command|app|bin|exe)$//'
}

# Escapes a string for safe inclusion in a JSON string literal.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Escapes a field for safe inclusion in CSV output (RFC 4180).
csv_escape() {
    local s="$1"
    if [[ "$s" == *,* || "$s" == *\"* || "$s" == *$'\n'* || "$s" == *$'\r'* ]]; then
        s="${s//\"/\"\"}"
        printf '"%s"' "$s"
    else
        printf '%s' "$s"
    fi
}

# Resolves a path to its absolute, canonical form. Delegates to `realpath`
# when available (macOS Big Sur+, all modern Linux); otherwise uses a pure
# POSIX fallback that resolves one level of symlink and canonicalizes the
# containing directory via `cd ... && pwd -P`.
_realpath() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null
        return
    fi
    local p="$1" d f target
    if [[ -L "$p" ]]; then
        target=$(readlink "$p")
        if [[ "$target" != /* ]]; then
            target="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)/$target"
        fi
        p="$target"
    fi
    d=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
    f=$(basename "$p")
    printf '%s/%s\n' "$d" "$f"
}

# Errors out with a hint block if $DEST_DIR is not writable. Call before
# any operation that mutates the symlink directory.
require_writable_dest() {
    if [[ ! -w "$DEST_DIR" ]]; then
        echo -e "${C_RED}Error:${C_RESET} Cannot write to '$DEST_DIR'." >&2
        echo "" >&2
        echo -e "${C_BLUE}Hint:${C_RESET} check permissions, try:" >&2
        echo "  chmod u+w \"$DEST_DIR\"" >&2
        echo "  # or pick a writable location:" >&2
        echo "  export SYM_DIR=\"\$HOME/.local/bin\"" >&2
        exit 3
    fi
}

# Atomically replaces (or creates) a symlink at $2 pointing to $1. Creates
# a temp symlink next to the destination, then `mv` (rename(2)) into place
# so there is never a window where the destination is missing.
atomic_symlink() {
    local src="$1" dst="$2"
    local tmp="${dst}.sym.tmp.$$"
    if ! ln -s "$src" "$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    if ! mv -f "$tmp" "$dst" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    return 0
}

# Installs a signal trap (INT/TERM) that prints a warning and exits 130.
# Intended for bulk-mutation functions; call once near the top.
install_interrupt_trap() {
    trap 'echo >&2; warn "Interrupted, partial changes may remain"; exit 130' INT TERM
}

# Writes a single-entry undo journal record after a successful mutation.
# Internal format uses ASCII Unit Separator (\x1F) so empty middle fields
# survive (bash `read` collapses adjacent whitespace delimiters, but not
# non-whitespace ones):
#   op<US><op_type>
#   ts<US><iso8601>
#   entry<US><name><US><old_target><US><new_target>
# Paths containing \x1F or newline are not supported in undo state.
# Args: op_type, link_name, old_target (may be empty), new_target (may be empty)
record_last_op() {
    local op="$1" name="$2" old="$3" new="$4"
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    local ts us=$'\x1f'
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    {
        printf 'op%s%s\n' "$us" "$op"
        printf 'ts%s%s\n' "$us" "$ts"
        printf 'entry%s%s%s%s%s%s\n' "$us" "$name" "$us" "$old" "$us" "$new"
    } > "$LAST_OP_FILE" 2>/dev/null || return 0
}

# Writes a bulk-op undo record. Accepts an op_type, then newline-separated
# "name|old_target|new_target" tuples on stdin.
record_last_op_bulk() {
    local op="$1"
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    local ts us=$'\x1f'
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    {
        printf 'op%s%s\n' "$us" "$op"
        printf 'ts%s%s\n' "$us" "$ts"
        local name old new
        while IFS='|' read -r name old new; do
            [[ -z "$name" ]] && continue
            printf 'entry%s%s%s%s%s%s\n' "$us" "$name" "$us" "$old" "$us" "$new"
        done
    } > "$LAST_OP_FILE" 2>/dev/null || return 0
}

# Clears the undo journal (after a successful undo).
clear_last_op() {
    rm -f "$LAST_OP_FILE" 2>/dev/null || true
}

# Checks if destination directory is in PATH
check_path() {
    if [[ ":$PATH:" != *":$DEST_DIR:"* ]]; then
        warn "The directory '$DEST_DIR' is not in your PATH."
        warn "Add it to your PATH to use the created symbolic links:"
        warn "  export PATH=\"\$PATH:$DEST_DIR\""
    fi
}

# Prompts user for confirmation (returns 0 for yes, 1 for no)
confirm() {
    local prompt="$1"
    local response

    # In force mode, always return yes
    if [[ "$FORCE_MODE" == true ]]; then
        return 0
    fi

    read -r -p "$prompt (y/N): " response
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# === CORE FUNCTIONS ===

# Displays version information
show_version() {
    echo "$SCRIPT_NAME version $VERSION"
}

# Displays help information
show_help() {
    echo -e "${C_BOLD}sym${C_RESET} - Symbolic Link Manager v${VERSION}"
    echo ""
    echo -e "${C_BOLD}USAGE:${C_RESET}"
    echo "    sym [OPTIONS] <command> [ARGS...]"
    echo "    sym [OPTIONS] [link_name] <source_path>"
    echo ""
    echo -e "${C_BOLD}COMMANDS:${C_RESET}"
    echo -e "    ${C_GREEN}ls${C_RESET} [--broken] [--name=GLOB] [--format=FORMAT]"
    echo "        Lists all symbolic links in '$DEST_DIR'."
    echo "        --broken    Show only broken links"
    echo "        --name      Filter by shell glob (e.g. --name='my*')"
    echo "        --format    Output format: text (default), json, csv"
    echo ""
    echo -e "    ${C_GREEN}info${C_RESET} <link_name>"
    echo "        Shows detailed information about a symbolic link."
    echo ""
    echo -e "    ${C_GREEN}rm${C_RESET} <link_name> | --match <glob>"
    echo "        Removes a symbolic link from '$DEST_DIR'. --match removes"
    echo "        all links whose name matches the shell glob."
    echo ""
    echo -e "    ${C_GREEN}verify${C_RESET}"
    echo "        Checks all symbolic links and reports broken ones."
    echo "        Exits non-zero when broken links exist."
    echo ""
    echo -e "    ${C_GREEN}fix${C_RESET}"
    echo "        Removes all broken symbolic links."
    echo ""
    echo -e "    ${C_GREEN}create${C_RESET} [link_name] <source_path> | --from <dir>"
    echo "        Creates a symbolic link. If link_name is omitted, you'll be prompted."
    echo "        --from <dir>  Batch-create links for every file in <dir> (top-level)."
    echo "        You can also use: sym [link_name] <source_path>"
    echo ""
    echo -e "    ${C_GREEN}edit${C_RESET} <link_name> <new_target>"
    echo "        Atomically retargets an existing symbolic link."
    echo ""
    echo -e "    ${C_GREEN}completion${C_RESET} <bash|zsh|fish>"
    echo "        Prints a shell completion script to stdout."
    echo ""
    echo -e "    ${C_GREEN}undo${C_RESET}"
    echo "        Reverses the most recent create/rm/edit/fix/batch operation."
    echo ""
    echo -e "    ${C_GREEN}snapshot${C_RESET} save [<file>] | list | restore <file>"
    echo "        Capture and restore the full state of '$DEST_DIR' as JSON."
    echo ""
    echo -e "${C_BOLD}OPTIONS:${C_RESET}"
    echo "    -h, --help          Show this help message"
    echo "    -v, --version       Show version information"
    echo "    -f, --force         Skip confirmation prompts"
    echo "    -n, --dry-run       Show what would be done without doing it"
    echo ""
    echo -e "${C_BOLD}EXAMPLES:${C_RESET}"
    echo "    # Create a symlink named 'sublime' pointing to Sublime Text"
    echo "    sym sublime /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl"
    echo ""
    echo "    # List all symbolic links"
    echo "    sym ls"
    echo ""
    echo "    # Show only broken links"
    echo "    sym ls --broken"
    echo ""
    echo "    # Show info about a link"
    echo "    sym info sublime"
    echo ""
    echo "    # Remove a link"
    echo "    sym rm sublime"
    echo ""
    echo "    # Create without prompt"
    echo "    sym -f mylink /path/to/file"
    echo ""
    echo "    # Preview what would happen"
    echo "    sym -n mylink /path/to/file"
    echo ""
    echo -e "${C_BOLD}ENVIRONMENT:${C_RESET}"
    echo "    SYM_DIR         Directory for symbolic links (default: ~/.local/bin)"
    echo "    SYM_STATE_DIR   Directory for undo journal and snapshots"
    echo "                    (default: ~/.local/share/sym)"
    echo "    NO_COLOR        Disable colored output"
    echo ""
    echo "For more information, visit: https://github.com/11ways/sym"
}

# Lists all symbolic links with formatting
list_symlinks() {
    local show_broken_only=false
    local format="$OUTPUT_FORMAT"
    local name_glob=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --broken)
                show_broken_only=true
                shift
                ;;
            --format=*)
                format="${1#*=}"
                shift
                ;;
            --name=*)
                name_glob="${1#*=}"
                shift
                ;;
            --name)
                shift
                [[ $# -eq 0 ]] && error_exit "--name requires a value" 4
                name_glob="$1"
                shift
                ;;
            *)
                error_exit "Unknown option for ls: $1" 4
                ;;
        esac
    done

    # Validate format
    if [[ ! "$format" =~ ^(text|json|csv)$ ]]; then
        error_exit "Invalid format: $format. Use text, json, or csv." 4
    fi

    # Find all symlinks and sort alphabetically
    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)

    if [[ -z "$link_paths" ]]; then
        if [[ "$format" == "text" ]]; then
            echo ""
            echo -e "Existing symbolic links in '${C_BLUE}${DEST_DIR/#$HOME/\~}${C_RESET}':"
            echo ""
            echo "        (No symbolic links found)"
        elif [[ "$format" == "json" ]]; then
            echo "[]"
        elif [[ "$format" == "csv" ]]; then
            echo "name,target,status,size,created"
        fi
        return 0
    fi

    # Collect data
    local -a link_names=()
    local -a target_paths=()
    local -a is_broken=()
    local -a sizes=()
    local -a dates=()
    local max_len=0

    while IFS= read -r link; do
        local name
        name=$(basename "$link")

        local raw_target
        raw_target=$(readlink "$link")

        local target=""
        local broken=false

        # Check if target exists. Test the link itself (`-e "$link"`) so that
        # relative symlink targets are resolved against the symlink's directory
        # rather than the caller's CWD.
        if [[ -e "$link" ]]; then
            target=$(_realpath "$link" 2>/dev/null || echo "$raw_target")
            [[ -z "$target" ]] && target="$raw_target"
            broken=false
        else
            target="$raw_target"
            broken=true
        fi

        # Skip if we only want broken links and this isn't broken
        if [[ "$show_broken_only" == true && "$broken" == false ]]; then
            continue
        fi

        # Skip if --name glob is set and this name doesn't match (unquoted
        # RHS enables shell glob matching).
        if [[ -n "$name_glob" && ! "$name" == $name_glob ]]; then
            continue
        fi

        link_names+=("$name")
        target_paths+=("$target")
        is_broken+=("$broken")

        # Get additional info
        local size
        size=$(get_file_size "$target")
        sizes+=("$size")

        local date
        date=$(get_creation_date "$link")
        dates+=("$date")

        # Track max length for alignment
        if (( ${#name} > max_len )); then
            max_len=${#name}
        fi
    done <<< "$link_paths"

    # Check if we have any links to show
    if [[ ${#link_names[@]} -eq 0 ]]; then
        if [[ "$format" == "text" ]]; then
            echo ""
            echo -e "Existing symbolic links in '${C_BLUE}${DEST_DIR/#$HOME/\~}${C_RESET}':"
            echo ""
            echo "        (No symbolic links found)"
        elif [[ "$format" == "json" ]]; then
            echo "[]"
        elif [[ "$format" == "csv" ]]; then
            echo "name,target,status,size,created"
        fi
        return 0
    fi

    # Output based on format
    if [[ "$format" == "json" ]]; then
        echo "["
        for i in "${!link_names[@]}"; do
            local comma=""
            [[ $i -lt $((${#link_names[@]} - 1)) ]] && comma=","

            local status="ok"
            [[ "${is_broken[i]}" == true ]] && status="broken"

            local j_name j_target j_size j_date
            j_name=$(json_escape "${link_names[i]}")
            j_target=$(json_escape "${target_paths[i]/#$HOME/\~}")
            j_size=$(json_escape "${sizes[i]}")
            j_date=$(json_escape "${dates[i]}")

            cat << EOF
  {
    "name": "$j_name",
    "target": "$j_target",
    "status": "$status",
    "size": "$j_size",
    "created": "$j_date"
  }$comma
EOF
        done
        echo "]"

    elif [[ "$format" == "csv" ]]; then
        echo "name,target,status,size,created"
        for i in "${!link_names[@]}"; do
            local status="ok"
            [[ "${is_broken[i]}" == true ]] && status="broken"

            printf '%s,%s,%s,%s,%s\n' \
                "$(csv_escape "${link_names[i]}")" \
                "$(csv_escape "${target_paths[i]/#$HOME/\~}")" \
                "$(csv_escape "$status")" \
                "$(csv_escape "${sizes[i]}")" \
                "$(csv_escape "${dates[i]}")"
        done

    else  # text format
        echo ""
        echo -e "Existing symbolic links in '${C_BLUE}${DEST_DIR/#$HOME/\~}${C_RESET}':"
        echo ""

        for i in "${!link_names[@]}"; do
            if [[ "${is_broken[i]}" == true ]]; then
                printf "        ${C_RED}%*s${C_RESET} ${C_GRAY}→${C_RESET} ${C_BLUE}%s${C_RESET} ${C_RED}(Does not exist!)${C_RESET}\\n" \
                    "$max_len" "${link_names[i]}" "${target_paths[i]/#$HOME/\~}"
            else
                printf "        ${C_WHITE}%*s${C_RESET} ${C_GRAY}→${C_RESET} ${C_BLUE}%s${C_RESET}\\n" \
                    "$max_len" "${link_names[i]}" "${target_paths[i]/#$HOME/\~}"
            fi
        done
        echo ""
    fi
}

# Shows detailed information about a symbolic link
show_link_info() {
    local link_name="$1"
    local dest_link="$DEST_DIR/$link_name"

    # Validate link name
    validate_link_name "$link_name"

    # Check if the symlink exists
    if [[ ! -L "$dest_link" ]]; then
        error_exit "The symlink '$link_name' does not exist." 2
    fi

    # Get the target
    local target
    target=$(readlink "$dest_link")

    # Try to resolve to real path if it exists. Test the link itself so
    # relative targets resolve against the symlink's directory, not CWD.
    if [[ -e "$dest_link" ]]; then
        local resolved
        resolved=$(_realpath "$dest_link" 2>/dev/null) || resolved=""
        [[ -n "$resolved" ]] && target="$resolved"
    fi

    # Get metadata
    local created_date
    created_date=$(get_creation_date "$dest_link")

    local target_size
    target_size=$(get_file_size "$target")

    local path_type
    path_type=$(get_path_type "$target")

    # Display information
    echo ""
    echo -e "  ${C_GRAY}→${C_RESET} From:    ${C_BLUE}${dest_link/#$HOME/\~}${C_RESET}"
    echo -e "  ${C_GRAY}→${C_RESET} To:      ${C_BLUE}${target/#$HOME/\~}${C_RESET}"

    if [[ -n "$created_date" ]]; then
        echo -e "  ${C_GRAY}→${C_RESET} Created: $created_date"
    fi

    if [[ -n "$target_size" ]]; then
        echo -e "  ${C_GRAY}→${C_RESET} Size:    $target_size"
    fi

    case "$path_type" in
        broken-symlink|not-found)
            echo -e "  ${C_GRAY}→${C_RESET} Status:  ${C_RED}Target does not exist${C_RESET}"
            ;;
        directory)
            echo -e "  ${C_GRAY}→${C_RESET} Type:    Directory"
            ;;
        file)
            echo -e "  ${C_GRAY}→${C_RESET} Type:    File"
            ;;
    esac

    echo ""
    echo "To delete:"
    echo "   sym rm $link_name"
    echo ""
    echo "To change the destination:"
    echo "   sym $link_name <new_destination>"
    echo ""
}

# Creates a symbolic link
create_link() {
    local source_input="$1"
    local link_name="$2"

    # Validate link name
    validate_link_name "$link_name"

    # Check if source exists
    if [[ ! -e "$source_input" ]]; then
        error_exit "Source not found at '$source_input'.\n${C_BLUE}Hint:${C_RESET} Make sure the path is correct and the file exists." 2
    fi

    require_writable_dest

    # Resolve source to absolute path
    local source_path
    source_path=$(_realpath "$source_input") || source_path="$source_input"
    local dest_link="$DEST_DIR/$link_name"

    # Track whether we're replacing an existing link (for the undo journal).
    local prev_target=""

    # Check if destination exists
    if [[ -e "$dest_link" ]] || [[ -L "$dest_link" ]]; then
        if [[ -L "$dest_link" ]]; then
            # It's a symlink
            local current_target
            current_target=$(readlink "$dest_link")
            prev_target="$current_target"

            # Resolve if possible. Test the link itself so relative targets
            # resolve against the symlink's directory, not CWD.
            local resolved_current="$current_target"
            if [[ -e "$dest_link" ]]; then
                local resolved
                resolved=$(_realpath "$dest_link" 2>/dev/null) || resolved=""
                [[ -n "$resolved" ]] && resolved_current="$resolved"
            fi

            # Check if pointing to same place
            if [[ "$resolved_current" == "$source_path" ]]; then
                info "Symbolic link '$link_name' already points to '${source_path/#$HOME/\~}'."
                return 0
            fi

            # Different target
            echo "A symbolic link named '$link_name' already exists."
            echo "  Current target: ${resolved_current/#$HOME/\~}"
            echo "  New target:     ${source_path/#$HOME/\~}"
            echo ""

            if ! confirm "Do you want to override it?"; then
                echo "Operation cancelled."
                return 0
            fi
        else
            # Regular file exists
            error_exit "A file (not a symlink) already exists at '$dest_link'." 1
        fi
    fi

    # Create (or atomically replace) the symlink
    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would create symbolic link:"
        echo -e "  ${C_GRAY}→${C_RESET} From: ${source_path/#$HOME/\~}"
        echo -e "  ${C_GRAY}→${C_RESET} To:   ${dest_link/#$HOME/\~}"
    else
        atomic_symlink "$source_path" "$dest_link" \
            || error_exit "Failed to create symbolic link." 3
        success "Successfully created symbolic link:"
        echo -e "  ${C_GRAY}→${C_RESET} From: ${source_path/#$HOME/\~}"
        echo -e "  ${C_GRAY}→${C_RESET} To:   ${dest_link/#$HOME/\~}"
        if [[ -n "$prev_target" ]]; then
            record_last_op "edit" "$link_name" "$prev_target" "$source_path"
        else
            record_last_op "create" "$link_name" "" "$source_path"
        fi
    fi
}

# Removes a symbolic link
remove_link() {
    local link_name="$1"
    local dest_link="$DEST_DIR/$link_name"

    # Validate link name
    validate_link_name "$link_name"

    # Check if exists
    if [[ ! -L "$dest_link" ]]; then
        error_exit "The symlink '$link_name' does not exist." 2
    fi

    require_writable_dest

    # Capture target for the undo journal before we remove the link.
    local old_target
    old_target=$(readlink "$dest_link" 2>/dev/null || echo "")

    # Show info
    show_link_info "$link_name"

    # Confirm deletion
    if ! confirm "Delete this symbolic link?"; then
        echo "Operation cancelled."
        return 0
    fi

    # Remove
    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would delete symbolic link '$link_name'"
    else
        rm "$dest_link" || error_exit "Failed to delete symbolic link." 3
        success "Symbolic link '$link_name' has been deleted."
        record_last_op "rm" "$link_name" "$old_target" ""
    fi
}

# Verifies all symbolic links
verify_links() {
    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)

    if [[ -z "$link_paths" ]]; then
        info "No symbolic links found in '$DEST_DIR'."
        return 0
    fi

    local broken_count=0
    local total_count=0

    echo ""
    echo "Verifying symbolic links..."
    echo ""

    while IFS= read -r link; do
        local name
        name=$(basename "$link")
        local target
        target=$(readlink "$link")

        total_count=$((total_count + 1))

        # Test the link itself so relative targets resolve against the
        # symlink's directory, not the caller's CWD.
        if [[ ! -e "$link" ]]; then
            broken_count=$((broken_count + 1))
            echo -e "  ${C_RED}✗${C_RESET} $name ${C_GRAY}→${C_RESET} ${target/#$HOME/\~} ${C_RED}(broken)${C_RESET}"
        else
            echo -e "  ${C_GREEN}✓${C_RESET} $name ${C_GRAY}→${C_RESET} ${target/#$HOME/\~}"
        fi
    done <<< "$link_paths"

    echo ""
    if [[ $broken_count -eq 0 ]]; then
        success "All $total_count symbolic links are valid!"
        return 0
    else
        warn "Found $broken_count broken link(s) out of $total_count total."
        echo ""
        echo "To remove broken links, run: sym fix"
        # Non-zero exit so CI / pre-commit hooks surface the failure.
        exit 1
    fi
}

# Fixes (removes) all broken symbolic links
fix_links() {
    install_interrupt_trap

    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)

    if [[ -z "$link_paths" ]]; then
        info "No symbolic links found in '$DEST_DIR'."
        return 0
    fi

    local broken_links=()

    # Find broken links. Test the link itself so relative targets resolve
    # against the symlink's directory, not the caller's CWD.
    while IFS= read -r link; do
        if [[ ! -e "$link" ]]; then
            broken_links+=("$link")
        fi
    done <<< "$link_paths"

    # Check if any broken links found
    if [[ ${#broken_links[@]} -eq 0 ]]; then
        success "No broken links found!"
        return 0
    fi

    require_writable_dest

    # Show what will be removed
    echo ""
    echo "The following broken links will be removed:"
    echo ""
    for link in "${broken_links[@]}"; do
        local name
        name=$(basename "$link")
        local target
        target=$(readlink "$link")
        echo -e "  ${C_RED}✗${C_RESET} $name ${C_GRAY}→${C_RESET} ${target/#$HOME/\~}"
    done
    echo ""

    # Confirm
    if ! confirm "Remove ${#broken_links[@]} broken link(s)?"; then
        echo "Operation cancelled."
        return 0
    fi

    # Remove broken links. For the undo journal, buffer each successful
    # removal as "name|old_target|" so `sym undo` can recreate them.
    local removed_count=0
    local undo_buffer=""
    for link in "${broken_links[@]}"; do
        local name target
        name=$(basename "$link")
        target=$(readlink "$link" 2>/dev/null || echo "")
        if [[ "$DRY_RUN_MODE" == true ]]; then
            info "[DRY RUN] Would remove: $name"
            removed_count=$((removed_count + 1))
        else
            if rm "$link" 2>/dev/null; then
                removed_count=$((removed_count + 1))
                undo_buffer+="${name}|${target}|"$'\n'
            else
                warn "Failed to remove: $name"
            fi
        fi
    done

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would remove $removed_count broken link(s)"
    else
        success "Removed $removed_count broken link(s)!"
        if [[ -n "$undo_buffer" ]]; then
            printf '%s' "$undo_buffer" | record_last_op_bulk "fix"
        fi
    fi
}

# Batch-creates symlinks for every regular file in a source directory
# (top-level only). Skips dotfiles, existing links pointing to the same
# target, and entries whose inferred name already links somewhere else
# (unless -f/--force). Records a single 'batch_create' undo op.
batch_create() {
    local src_dir="$1"
    install_interrupt_trap

    if [[ ! -d "$src_dir" ]]; then
        error_exit "Source directory not found: '$src_dir'" 2
    fi

    require_writable_dest

    local src_abs
    src_abs=$(_realpath "$src_dir") || src_abs="$src_dir"

    local -a planned_names=()
    local -a planned_sources=()
    local -a planned_prev=()

    for entry in "$src_abs"/*; do
        [[ -e "$entry" ]] || continue
        # Skip directories and dotfiles (basename starting with .)
        local base
        base=$(basename "$entry")
        [[ "$base" == .* ]] && continue
        [[ -d "$entry" ]] && continue
        [[ ! -f "$entry" ]] && continue

        local name
        name=$(strip_extensions "$base")
        [[ -z "$name" ]] && continue

        local dest="$DEST_DIR/$name"
        local prev=""
        if [[ -L "$dest" ]]; then
            prev=$(readlink "$dest" 2>/dev/null || echo "")
            local resolved=""
            if [[ -e "$dest" ]]; then
                resolved=$(_realpath "$dest" 2>/dev/null) || resolved=""
            fi
            if [[ "$resolved" == "$entry" || "$prev" == "$entry" ]]; then
                # Already linked to this source; idempotent skip.
                continue
            fi
            if [[ "$FORCE_MODE" != true ]]; then
                warn "Skipping '$name': already linked to '${prev/#$HOME/\~}' (use -f to override)"
                continue
            fi
        elif [[ -e "$dest" ]]; then
            warn "Skipping '$name': a non-symlink file exists at destination"
            continue
        fi

        planned_names+=("$name")
        planned_sources+=("$entry")
        planned_prev+=("$prev")
    done

    if [[ ${#planned_names[@]} -eq 0 ]]; then
        info "Nothing to create from '$src_dir'."
        return 0
    fi

    echo ""
    echo "Will create ${#planned_names[@]} symbolic link(s) in '${DEST_DIR/#$HOME/\~}':"
    local i
    for (( i=0; i<${#planned_names[@]}; i++ )); do
        echo -e "  ${C_GREEN}+${C_RESET} ${planned_names[i]} ${C_GRAY}→${C_RESET} ${planned_sources[i]/#$HOME/\~}"
    done
    echo ""

    if ! confirm "Proceed?"; then
        echo "Operation cancelled."
        return 0
    fi

    local created=0
    local undo_buffer=""
    for (( i=0; i<${#planned_names[@]}; i++ )); do
        local name="${planned_names[i]}"
        local src="${planned_sources[i]}"
        local prev="${planned_prev[i]}"
        local dest="$DEST_DIR/$name"
        if [[ "$DRY_RUN_MODE" == true ]]; then
            info "[DRY RUN] Would link $name → ${src/#$HOME/\~}"
            created=$((created + 1))
        else
            if atomic_symlink "$src" "$dest"; then
                created=$((created + 1))
                undo_buffer+="${name}|${prev}|${src}"$'\n'
            else
                warn "Failed to create '$name'"
            fi
        fi
    done

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would create $created link(s)"
    else
        success "Created $created link(s)."
        if [[ -n "$undo_buffer" ]]; then
            printf '%s' "$undo_buffer" | record_last_op_bulk "batch_create"
        fi
    fi
}

# Batch-removes symlinks whose names match a shell glob. Records a single
# 'batch_rm' undo op so the removals can be restored.
batch_remove() {
    local glob="$1"
    install_interrupt_trap

    if [[ -z "$glob" ]]; then
        error_exit "--match requires a glob pattern" 4
    fi

    require_writable_dest

    local -a matches=()
    local -a prev_targets=()

    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        local name
        name=$(basename "$link")
        if [[ "$name" == $glob ]]; then
            matches+=("$name")
            prev_targets+=("$(readlink "$link" 2>/dev/null || echo "")")
        fi
    done <<< "$link_paths"

    if [[ ${#matches[@]} -eq 0 ]]; then
        info "No links match '$glob'."
        return 0
    fi

    echo ""
    echo "The following ${#matches[@]} link(s) match '$glob':"
    local i
    for (( i=0; i<${#matches[@]}; i++ )); do
        echo -e "  ${C_RED}✗${C_RESET} ${matches[i]} ${C_GRAY}→${C_RESET} ${prev_targets[i]/#$HOME/\~}"
    done
    echo ""

    if ! confirm "Remove all ${#matches[@]} link(s)?"; then
        echo "Operation cancelled."
        return 0
    fi

    local removed=0
    local undo_buffer=""
    for (( i=0; i<${#matches[@]}; i++ )); do
        local name="${matches[i]}"
        local target="${prev_targets[i]}"
        if [[ "$DRY_RUN_MODE" == true ]]; then
            info "[DRY RUN] Would remove: $name"
            removed=$((removed + 1))
        else
            if rm "$DEST_DIR/$name" 2>/dev/null; then
                removed=$((removed + 1))
                undo_buffer+="${name}|${target}|"$'\n'
            else
                warn "Failed to remove '$name'"
            fi
        fi
    done

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would remove $removed link(s)"
    else
        success "Removed $removed link(s)."
        if [[ -n "$undo_buffer" ]]; then
            printf '%s' "$undo_buffer" | record_last_op_bulk "batch_rm"
        fi
    fi
}

# Retargets an existing symlink to a new source (atomic).
edit_link() {
    local link_name="$1"
    local new_source="$2"
    local dest_link="$DEST_DIR/$link_name"

    validate_link_name "$link_name"

    if [[ ! -L "$dest_link" ]]; then
        error_exit "The symlink '$link_name' does not exist. Use 'sym create' to make a new one." 2
    fi

    if [[ ! -e "$new_source" ]]; then
        error_exit "Source not found at '$new_source'." 2
    fi

    require_writable_dest

    local new_path old_target
    new_path=$(_realpath "$new_source") || new_path="$new_source"
    old_target=$(readlink "$dest_link" 2>/dev/null || echo "")

    # Short-circuit if unchanged
    local resolved_old="$old_target"
    if [[ -e "$dest_link" ]]; then
        local r
        r=$(_realpath "$dest_link" 2>/dev/null) || r=""
        [[ -n "$r" ]] && resolved_old="$r"
    fi
    if [[ "$resolved_old" == "$new_path" ]]; then
        info "'$link_name' already points to '${new_path/#$HOME/\~}'."
        return 0
    fi

    echo "Retargeting '$link_name':"
    echo "  From: ${resolved_old/#$HOME/\~}"
    echo "  To:   ${new_path/#$HOME/\~}"
    echo ""

    if ! confirm "Apply this change?"; then
        echo "Operation cancelled."
        return 0
    fi

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would retarget '$link_name'"
    else
        atomic_symlink "$new_path" "$dest_link" \
            || error_exit "Failed to retarget symbolic link." 3
        success "Retargeted '$link_name'."
        record_last_op "edit" "$link_name" "$old_target" "$new_path"
    fi
}

# Prints a shell-completion script to stdout for bash, zsh, or fish.
print_completion() {
    local shell="${1:-}"
    case "$shell" in
        bash)
            cat <<'BASH_EOF'
# sym bash completion. Install via:
#   sym completion bash > /usr/local/etc/bash_completion.d/sym
# or source from your ~/.bashrc.
_sym_complete() {
    local cur prev commands link_names sym_dir
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="ls info rm verify fix create edit completion snapshot undo"
    sym_dir="${SYM_DIR:-$HOME/.local/bin}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands --help --version" -- "$cur") )
        return
    fi

    case "$prev" in
        info|rm|edit|remove|delete|show)
            if [[ -d "$sym_dir" ]]; then
                link_names=$(find "$sym_dir" -maxdepth 1 -type l 2>/dev/null | while read -r l; do basename "$l"; done)
                COMPREPLY=( $(compgen -W "$link_names" -- "$cur") )
            fi
            return
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
            return
            ;;
        snapshot)
            COMPREPLY=( $(compgen -W "save list restore" -- "$cur") )
            return
            ;;
    esac

    if [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--help --version --force --dry-run --broken --format= --name= --from --match" -- "$cur") )
        return
    fi

    COMPREPLY=( $(compgen -f -- "$cur") )
}
complete -F _sym_complete sym
BASH_EOF
            ;;
        zsh)
            cat <<'ZSH_EOF'
#compdef sym
# sym zsh completion. Install by placing this file as _sym in a directory
# on your $fpath (e.g. ~/.zsh/completions/_sym) and adding:
#   fpath=(~/.zsh/completions $fpath)
#   autoload -Uz compinit && compinit

_sym_link_names() {
    local sym_dir="${SYM_DIR:-$HOME/.local/bin}"
    local -a names
    if [[ -d "$sym_dir" ]]; then
        names=( "$sym_dir"/*(@N:t) )
    fi
    _describe 'symlink' names
}

_sym() {
    local -a commands
    commands=(
        'ls:list symbolic links'
        'info:show link details'
        'rm:remove a link'
        'verify:check all links'
        'fix:remove broken links'
        'create:create a new link'
        'edit:retarget an existing link'
        'completion:print shell completion'
        'snapshot:save, list, or restore snapshots'
        'undo:reverse the last mutating operation'
    )
    if (( CURRENT == 2 )); then
        _describe 'command' commands
        return
    fi
    case "$words[2]" in
        info|rm|edit|remove|delete|show)
            _sym_link_names
            ;;
        completion)
            _values 'shell' bash zsh fish
            ;;
        snapshot)
            _values 'subcommand' save list restore
            ;;
        *)
            _files
            ;;
    esac
}
_sym "$@"
ZSH_EOF
            ;;
        fish)
            cat <<'FISH_EOF'
# sym fish completion. Install via:
#   sym completion fish > ~/.config/fish/completions/sym.fish
function __sym_link_names
    set -l sym_dir (set -q SYM_DIR; and echo $SYM_DIR; or echo $HOME/.local/bin)
    if test -d $sym_dir
        for l in $sym_dir/*
            if test -L $l
                basename $l
            end
        end
    end
end

complete -c sym -f
complete -c sym -n '__fish_use_subcommand' -a 'ls info rm verify fix create edit completion snapshot undo' -d 'sym command'
complete -c sym -n '__fish_seen_subcommand_from info rm edit remove delete show' -a '(__sym_link_names)'
complete -c sym -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
complete -c sym -n '__fish_seen_subcommand_from snapshot' -a 'save list restore'
complete -c sym -s h -l help -d 'Show help'
complete -c sym -s v -l version -d 'Show version'
complete -c sym -s f -l force -d 'Skip confirmations'
complete -c sym -s n -l dry-run -d 'Preview without writing'
FISH_EOF
            ;;
        *)
            error_exit "Unknown shell '$shell'. Supported: bash, zsh, fish." 4
            ;;
    esac
}

# Reverses the most recent mutating operation by replaying the undo journal
# in inverse: create → rm; rm → create; edit → retarget to old_target;
# fix/batch_rm → recreate each; batch_create → remove each.
undo_last_op() {
    if [[ ! -f "$LAST_OP_FILE" ]]; then
        info "Nothing to undo."
        return 0
    fi

    require_writable_dest

    local op=""
    local -a entry_names=()
    local -a entry_olds=()
    local -a entry_news=()
    local line name old new
    local us=$'\x1f'
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Split on Unit Separator (\x1F). Non-whitespace IFS preserves empty
        # middle fields (unlike tab, which bash collapses).
        local -a field
        IFS="$us" read -ra field <<< "$line"
        case "${field[0]:-}" in
            op) op="${field[1]:-}" ;;
            entry)
                entry_names+=("${field[1]:-}")
                entry_olds+=("${field[2]:-}")
                entry_news+=("${field[3]:-}")
                ;;
        esac
    done < "$LAST_OP_FILE"

    if [[ -z "$op" || ${#entry_names[@]} -eq 0 ]]; then
        warn "Undo journal is empty or unreadable."
        clear_last_op
        return 0
    fi

    echo ""
    echo "Undoing last operation: $op (${#entry_names[@]} entr$( [[ ${#entry_names[@]} -eq 1 ]] && echo y || echo ies ))"
    echo ""

    # `restore` is special: each entry's inverse depends on which fields are
    # populated (empty old ↔ empty new encodes create vs. rm vs. retarget).
    # Helper maps (op, old, new) → action ∈ (remove, recreate, retarget).
    _undo_action() {
        local lop="$1" lold="$2" lnew="$3"
        case "$lop" in
            create|batch_create)       echo "remove" ;;
            rm|fix|batch_rm)            echo "recreate" ;;
            edit)                       echo "retarget" ;;
            restore)
                if [[ -z "$lold" && -n "$lnew" ]]; then echo "remove"
                elif [[ -n "$lold" && -z "$lnew" ]]; then echo "recreate"
                elif [[ -n "$lold" && -n "$lnew" ]]; then echo "retarget"
                else echo "skip"
                fi
                ;;
            *) echo "skip" ;;
        esac
    }

    local i action
    for (( i=0; i<${#entry_names[@]}; i++ )); do
        name="${entry_names[i]}"
        old="${entry_olds[i]}"
        new="${entry_news[i]}"
        action=$(_undo_action "$op" "$old" "$new")
        case "$action" in
            remove)    echo -e "  ${C_RED}-${C_RESET} remove $name" ;;
            recreate)  echo -e "  ${C_GREEN}+${C_RESET} recreate $name → ${old/#$HOME/\~}" ;;
            retarget)  echo -e "  ${C_YELLOW}~${C_RESET} retarget $name → ${old/#$HOME/\~}" ;;
            skip)
                warn "Unknown op '$op' in journal; skipping"
                return 0
                ;;
        esac
    done
    echo ""

    if ! confirm "Apply undo?"; then
        echo "Operation cancelled."
        return 0
    fi

    local applied=0
    for (( i=0; i<${#entry_names[@]}; i++ )); do
        name="${entry_names[i]}"
        old="${entry_olds[i]}"
        new="${entry_news[i]}"
        action=$(_undo_action "$op" "$old" "$new")
        local dest="$DEST_DIR/$name"
        case "$action" in
            remove)
                if [[ "$DRY_RUN_MODE" == true ]]; then
                    info "[DRY RUN] Would remove $name"
                else
                    rm -f "$dest" 2>/dev/null && applied=$((applied + 1))
                fi
                ;;
            recreate)
                if [[ -z "$old" ]]; then
                    warn "Cannot recreate $name (no old target in journal)"
                    continue
                fi
                if [[ "$DRY_RUN_MODE" == true ]]; then
                    info "[DRY RUN] Would recreate $name"
                else
                    if atomic_symlink "$old" "$dest"; then
                        applied=$((applied + 1))
                    else
                        warn "Failed to recreate $name"
                    fi
                fi
                ;;
            retarget)
                if [[ -z "$old" ]]; then
                    warn "Cannot retarget $name (no old target in journal)"
                    continue
                fi
                if [[ "$DRY_RUN_MODE" == true ]]; then
                    info "[DRY RUN] Would retarget $name"
                else
                    if atomic_symlink "$old" "$dest"; then
                        applied=$((applied + 1))
                    else
                        warn "Failed to retarget $name"
                    fi
                fi
                ;;
        esac
    done

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would apply $applied undo operation(s)"
    else
        success "Undid $applied operation(s)."
        clear_last_op
    fi
}

# Saves a full snapshot of $DEST_DIR to a JSON file. If no path is given,
# writes to $SNAPSHOT_DIR/<timestamp>.json.
snapshot_save() {
    local target="${1:-}"
    mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || error_exit "Cannot create snapshot dir '$SNAPSHOT_DIR'." 3
    if [[ -z "$target" ]]; then
        local ts
        ts=$(date +"%Y%m%d-%H%M%S" 2>/dev/null || echo "snapshot")
        target="$SNAPSHOT_DIR/${ts}.json"
    fi

    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)

    {
        echo "{"
        echo "  \"sym_snapshot\": 1,"
        echo "  \"created\": \"$(json_escape "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")\","
        echo "  \"dir\": \"$(json_escape "$DEST_DIR")\","
        echo "  \"links\": ["
        local first=true name target_val
        while IFS= read -r link; do
            [[ -z "$link" ]] && continue
            name=$(basename "$link")
            target_val=$(readlink "$link" 2>/dev/null || echo "")
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "    ,"
            fi
            echo "    {"
            echo "      \"name\": \"$(json_escape "$name")\","
            echo "      \"target\": \"$(json_escape "$target_val")\""
            echo "    }"
        done <<< "$link_paths"
        echo "  ]"
        echo "}"
    } > "$target" || error_exit "Failed to write snapshot to '$target'." 3

    success "Snapshot saved: ${target/#$HOME/\~}"
}

# Lists available snapshot files in $SNAPSHOT_DIR.
snapshot_list() {
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        info "No snapshots found (dir does not exist: ${SNAPSHOT_DIR/#$HOME/\~})"
        return 0
    fi
    local files
    files=$(find "$SNAPSHOT_DIR" -maxdepth 1 -type f -name "*.json" 2>/dev/null | sort)
    if [[ -z "$files" ]]; then
        info "No snapshots found in '${SNAPSHOT_DIR/#$HOME/\~}'."
        return 0
    fi
    echo ""
    echo "Snapshots in '${SNAPSHOT_DIR/#$HOME/\~}':"
    echo ""
    local f name size
    while IFS= read -r f; do
        name=$(basename "$f")
        size=$(get_file_size "$f")
        echo -e "  ${C_BLUE}$name${C_RESET}  ${C_GRAY}$size${C_RESET}"
    done <<< "$files"
    echo ""
}

# Restores $DEST_DIR state from a snapshot file. Computes a delta vs.
# current state (removes, creates, retargets), confirms, then applies.
# Records the pre-restore state as a single undo op.
snapshot_restore() {
    local file="${1:-}"
    install_interrupt_trap

    if [[ -z "$file" ]]; then
        error_exit "'sym snapshot restore' requires a file path." 4
    fi
    if [[ ! -f "$file" ]]; then
        error_exit "Snapshot file not found: '$file'" 2
    fi

    require_writable_dest

    # Parse snapshot entries. Our snapshot format has one-field-per-line
    # objects, so we can extract name/target with a line-based scan.
    local -a snap_names=()
    local -a snap_targets=()
    local cur_name="" cur_target=""
    local in_obj=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            *'"name":'*)
                cur_name=$(printf '%s' "$line" | sed -E 's/.*"name": "(.*)".*/\1/')
                cur_name="${cur_name%,}"
                cur_name="${cur_name%\"}"
                in_obj=true
                ;;
            *'"target":'*)
                cur_target=$(printf '%s' "$line" | sed -E 's/.*"target": "(.*)".*/\1/')
                cur_target="${cur_target%,}"
                cur_target="${cur_target%\"}"
                ;;
            *'}'*)
                if [[ "$in_obj" == true && -n "$cur_name" ]]; then
                    snap_names+=("$cur_name")
                    snap_targets+=("$cur_target")
                fi
                cur_name=""
                cur_target=""
                in_obj=false
                ;;
        esac
    done < "$file"

    if [[ ${#snap_names[@]} -eq 0 ]]; then
        error_exit "Snapshot '$file' contained no links." 4
    fi

    # Collect current state
    local -a cur_names=()
    local -a cur_targets=()
    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        cur_names+=("$(basename "$link")")
        cur_targets+=("$(readlink "$link" 2>/dev/null || echo "")")
    done <<< "$link_paths"

    # Compute delta
    local -a to_remove=()
    local -a to_remove_targets=()
    local -a to_create=()
    local -a to_create_targets=()
    local -a to_retarget=()
    local -a to_retarget_old=()
    local -a to_retarget_new=()

    # Remove: in current but not in snapshot
    local i j found
    for (( i=0; i<${#cur_names[@]}; i++ )); do
        found=false
        for (( j=0; j<${#snap_names[@]}; j++ )); do
            if [[ "${cur_names[i]}" == "${snap_names[j]}" ]]; then
                found=true
                if [[ "${cur_targets[i]}" != "${snap_targets[j]}" ]]; then
                    to_retarget+=("${cur_names[i]}")
                    to_retarget_old+=("${cur_targets[i]}")
                    to_retarget_new+=("${snap_targets[j]}")
                fi
                break
            fi
        done
        if [[ "$found" == false ]]; then
            to_remove+=("${cur_names[i]}")
            to_remove_targets+=("${cur_targets[i]}")
        fi
    done
    # Create: in snapshot but not in current
    for (( j=0; j<${#snap_names[@]}; j++ )); do
        found=false
        for (( i=0; i<${#cur_names[@]}; i++ )); do
            if [[ "${snap_names[j]}" == "${cur_names[i]}" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            to_create+=("${snap_names[j]}")
            to_create_targets+=("${snap_targets[j]}")
        fi
    done

    if [[ ${#to_remove[@]} -eq 0 && ${#to_create[@]} -eq 0 && ${#to_retarget[@]} -eq 0 ]]; then
        success "Current state already matches snapshot."
        return 0
    fi

    echo ""
    echo "Snapshot restore plan:"
    local k
    for (( k=0; k<${#to_remove[@]}; k++ )); do
        echo -e "  ${C_RED}-${C_RESET} remove ${to_remove[k]}"
    done
    for (( k=0; k<${#to_retarget[@]}; k++ )); do
        echo -e "  ${C_YELLOW}~${C_RESET} retarget ${to_retarget[k]} → ${to_retarget_new[k]/#$HOME/\~}"
    done
    for (( k=0; k<${#to_create[@]}; k++ )); do
        echo -e "  ${C_GREEN}+${C_RESET} create ${to_create[k]} → ${to_create_targets[k]/#$HOME/\~}"
    done
    echo ""

    if ! confirm "Apply ${#to_remove[@]} remove(s), ${#to_retarget[@]} retarget(s), ${#to_create[@]} create(s)?"; then
        echo "Operation cancelled."
        return 0
    fi

    # Record pre-restore state as one undo op, so `sym undo` reverses the restore.
    local undo_buffer=""
    for (( k=0; k<${#to_remove[@]}; k++ )); do
        undo_buffer+="${to_remove[k]}|${to_remove_targets[k]}|"$'\n'
    done
    for (( k=0; k<${#to_retarget[@]}; k++ )); do
        undo_buffer+="${to_retarget[k]}|${to_retarget_old[k]}|${to_retarget_new[k]}"$'\n'
    done
    for (( k=0; k<${#to_create[@]}; k++ )); do
        undo_buffer+="${to_create[k]}||${to_create_targets[k]}"$'\n'
    done

    # Apply (unless dry-run)
    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would apply restore plan"
        return 0
    fi

    for (( k=0; k<${#to_remove[@]}; k++ )); do
        rm -f "$DEST_DIR/${to_remove[k]}" 2>/dev/null || warn "Failed to remove ${to_remove[k]}"
    done
    for (( k=0; k<${#to_retarget[@]}; k++ )); do
        atomic_symlink "${to_retarget_new[k]}" "$DEST_DIR/${to_retarget[k]}" \
            || warn "Failed to retarget ${to_retarget[k]}"
    done
    for (( k=0; k<${#to_create[@]}; k++ )); do
        atomic_symlink "${to_create_targets[k]}" "$DEST_DIR/${to_create[k]}" \
            || warn "Failed to create ${to_create[k]}"
    done

    success "Snapshot restored from '${file/#$HOME/\~}'."
    printf '%s' "$undo_buffer" | record_last_op_bulk "restore"
}

# === MAIN SCRIPT LOGIC ===

main() {
    # Setup colors
    setup_colors

    # Ensure destination directory exists
    if [[ ! -d "$DEST_DIR" ]]; then
        if ! mkdir -p "$DEST_DIR" 2>/dev/null; then
            error_exit "Cannot create directory '$DEST_DIR'. Check permissions." 3
        fi
    fi

    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --format=*)
                OUTPUT_FORMAT="${1#*=}"
                shift
                ;;
            -*)
                error_exit "Unknown option: $1\nUse --help for usage information." 4
                ;;
            *)
                # Not an option, break to handle commands
                break
                ;;
        esac
    done

    # No arguments after parsing options
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    # Parse command
    local command="$1"
    shift

    # Track whether this invocation actually created a symlink, so we only
    # warn about PATH for create operations (not for ls/info/verify/...).
    local did_create=false

    case "$command" in
        ls|list)
            list_symlinks "$@"
            ;;
        info|show)
            if [[ $# -ne 1 ]]; then
                error_exit "'sym info' requires exactly one argument (link name)." 4
            fi
            show_link_info "$1"
            ;;
        rm|remove|delete)
            if [[ $# -eq 2 && "$1" == "--match" ]]; then
                batch_remove "$2"
            elif [[ $# -eq 1 && "$1" == --match=* ]]; then
                batch_remove "${1#*=}"
            elif [[ $# -eq 1 ]]; then
                remove_link "$1"
            else
                error_exit "'sym rm' requires a link name or --match <glob>." 4
            fi
            ;;
        verify|check)
            verify_links
            ;;
        fix|clean)
            fix_links
            ;;
        edit|retarget)
            if [[ $# -ne 2 ]]; then
                error_exit "'sym edit' requires exactly two arguments (link name, new target)." 4
            fi
            edit_link "$1" "$2"
            ;;
        completion)
            if [[ $# -ne 1 ]]; then
                error_exit "'sym completion' requires one argument (bash, zsh, or fish)." 4
            fi
            print_completion "$1"
            exit 0
            ;;
        undo)
            if [[ $# -ne 0 ]]; then
                error_exit "'sym undo' takes no arguments." 4
            fi
            undo_last_op
            ;;
        snapshot)
            if [[ $# -lt 1 ]]; then
                error_exit "'sym snapshot' requires a subcommand (save, list, or restore)." 4
            fi
            local sub="$1"
            shift
            case "$sub" in
                save)     snapshot_save "$@" ;;
                list)     snapshot_list "$@" ;;
                restore)  snapshot_restore "$@" ;;
                *)        error_exit "Unknown snapshot subcommand '$sub'. Use save, list, or restore." 4 ;;
            esac
            ;;
        create|add)
            # sym create --from <dir> | [link_name] <source_path>
            if [[ $# -eq 2 && "$1" == "--from" ]]; then
                batch_create "$2"
                did_create=true
            elif [[ $# -eq 1 && "$1" == --from=* ]]; then
                batch_create "${1#*=}"
                did_create=true
            elif [[ $# -eq 1 ]]; then
                # Only source provided, prompt for name
                local source_path="$1"
                local inferred_name
                inferred_name=$(strip_extensions "$(basename "$source_path")")

                echo -n "Please enter the desired name for the link [$inferred_name]: "
                read -r link_name

                if [[ -z "$link_name" ]]; then
                    link_name="$inferred_name"
                fi

                if [[ -z "$link_name" ]]; then
                    error_exit "Link name cannot be empty." 4
                fi

                create_link "$source_path" "$link_name"
                did_create=true
            elif [[ $# -eq 2 ]]; then
                # Both name and source provided
                create_link "$2" "$1"
                did_create=true
            else
                error_exit "'sym create' requires 1 or 2 arguments." 4
            fi
            ;;
        *)
            # Not a recognized command, try to interpret as create
            # sym [link_name] <source_path> or sym <source_path>

            if [[ $# -eq 0 ]]; then
                # sym <something> with no more args
                # Check if it's an existing symlink to show info
                if [[ -L "$DEST_DIR/$command" ]]; then
                    show_link_info "$command"
                else
                    # Treat as source path
                    local source_path="$command"
                    local inferred_name
                    inferred_name=$(strip_extensions "$(basename "$source_path")")

                    echo -n "Please enter the desired name for the link [$inferred_name]: "
                    read -r link_name

                    if [[ -z "$link_name" ]]; then
                        link_name="$inferred_name"
                    fi

                    if [[ -z "$link_name" ]]; then
                        error_exit "Link name cannot be empty." 4
                    fi

                    create_link "$source_path" "$link_name"
                    did_create=true
                fi
            elif [[ $# -eq 1 ]]; then
                # sym <link_name> <source_path>
                create_link "$1" "$command"
                did_create=true
            else
                error_exit "Too many arguments.\nUse --help for usage information." 4
            fi
            ;;
    esac

    # Only warn about PATH when we actually created a symlink.
    if [[ "$did_create" == true ]]; then
        check_path
    fi
}

# Run main function
main "$@"
