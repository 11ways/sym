#!/usr/bin/env bash

# sym - Symbolic Link Manager
# Version: 1.0.0
# Author: Roel van Gils
# License: MIT
# Description: A simple, user-friendly tool for managing symbolic links in ~/.local/bin

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# === METADATA ===
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="sym"

# === CONFIGURATION ===
# The directory where symbolic links will be created.
readonly DEST_DIR="${SYM_DIR:-$HOME/.local/bin}"

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
    echo -e "    ${C_GREEN}ls${C_RESET} [--broken] [--format=FORMAT]"
    echo "        Lists all symbolic links in '$DEST_DIR'."
    echo "        --broken    Show only broken links"
    echo "        --format    Output format: text (default), json, csv"
    echo ""
    echo -e "    ${C_GREEN}info${C_RESET} <link_name>"
    echo "        Shows detailed information about a symbolic link."
    echo ""
    echo -e "    ${C_GREEN}rm${C_RESET} <link_name>"
    echo "        Removes a symbolic link from '$DEST_DIR'."
    echo ""
    echo -e "    ${C_GREEN}verify${C_RESET}"
    echo "        Checks all symbolic links and reports broken ones."
    echo ""
    echo -e "    ${C_GREEN}fix${C_RESET}"
    echo "        Removes all broken symbolic links."
    echo ""
    echo -e "    ${C_GREEN}create${C_RESET} [link_name] <source_path>"
    echo "        Creates a symbolic link. If link_name is omitted, you'll be prompted."
    echo "        You can also use: sym [link_name] <source_path>"
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
    echo "    NO_COLOR        Disable colored output"
    echo ""
    echo -e "${C_BOLD}EXIT CODES:${C_RESET}"
    echo "    0    Success"
    echo "    1    General error"
    echo "    2    Not found"
    echo "    3    Permission denied"
    echo "    4    Invalid argument"
    echo ""
    echo "For more information, visit: https://github.com/roelvangils/sym"
}

# Lists all symbolic links with formatting
list_symlinks() {
    local show_broken_only=false
    local format="$OUTPUT_FORMAT"

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

        # Check if target exists
        if [[ -e "$raw_target" ]]; then
            target=$(realpath "$raw_target" 2>/dev/null || echo "$raw_target")
            broken=false
        else
            target="$raw_target"
            broken=true
        fi

        # Skip if we only want broken links and this isn't broken
        if [[ "$show_broken_only" == true && "$broken" == false ]]; then
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

            cat << EOF
  {
    "name": "${link_names[i]}",
    "target": "${target_paths[i]/#$HOME/\~}",
    "status": "$status",
    "size": "${sizes[i]}",
    "created": "${dates[i]}"
  }$comma
EOF
        done
        echo "]"

    elif [[ "$format" == "csv" ]]; then
        echo "name,target,status,size,created"
        for i in "${!link_names[@]}"; do
            local status="ok"
            [[ "${is_broken[i]}" == true ]] && status="broken"

            echo "${link_names[i]},${target_paths[i]/#$HOME/\~},$status,${sizes[i]},${dates[i]}"
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

    # Try to resolve to real path if it exists
    if [[ -e "$target" ]]; then
        target=$(realpath "$target" 2>/dev/null || echo "$target")
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

    # Resolve source to absolute path
    local source_path
    source_path=$(realpath "$source_input")
    local dest_link="$DEST_DIR/$link_name"

    # Check if destination exists
    if [[ -e "$dest_link" ]] || [[ -L "$dest_link" ]]; then
        if [[ -L "$dest_link" ]]; then
            # It's a symlink
            local current_target
            current_target=$(readlink "$dest_link")

            # Resolve if possible
            if [[ -e "$current_target" ]]; then
                current_target=$(realpath "$current_target" 2>/dev/null || echo "$current_target")
            fi

            # Check if pointing to same place
            if [[ "$current_target" == "$source_path" ]]; then
                info "Symbolic link '$link_name' already points to '${source_path/#$HOME/\~}'."
                return 0
            fi

            # Different target
            echo "A symbolic link named '$link_name' already exists."
            echo "  Current target: ${current_target/#$HOME/\~}"
            echo "  New target:     ${source_path/#$HOME/\~}"
            echo ""

            if ! confirm "Do you want to override it?"; then
                echo "Operation cancelled."
                return 0
            fi

            if [[ "$DRY_RUN_MODE" == true ]]; then
                info "[DRY RUN] Would remove existing symlink"
            else
                rm "$dest_link"
                success "Removed existing symlink."
            fi
        else
            # Regular file exists
            error_exit "A file (not a symlink) already exists at '$dest_link'." 1
        fi
    fi

    # Create the symlink
    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would create symbolic link:"
        echo -e "  ${C_GRAY}→${C_RESET} From: ${source_path/#$HOME/\~}"
        echo -e "  ${C_GRAY}→${C_RESET} To:   ${dest_link/#$HOME/\~}"
    else
        ln -s "$source_path" "$dest_link" || error_exit "Failed to create symbolic link." 3
        success "Successfully created symbolic link:"
        echo -e "  ${C_GRAY}→${C_RESET} From: ${source_path/#$HOME/\~}"
        echo -e "  ${C_GRAY}→${C_RESET} To:   ${dest_link/#$HOME/\~}"
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

        ((total_count++))

        if [[ ! -e "$target" ]]; then
            ((broken_count++))
            echo -e "  ${C_RED}✗${C_RESET} $name ${C_GRAY}→${C_RESET} ${target/#$HOME/\~} ${C_RED}(broken)${C_RESET}"
        else
            echo -e "  ${C_GREEN}✓${C_RESET} $name ${C_GRAY}→${C_RESET} ${target/#$HOME/\~}"
        fi
    done <<< "$link_paths"

    echo ""
    if [[ $broken_count -eq 0 ]]; then
        success "All $total_count symbolic links are valid!"
    else
        warn "Found $broken_count broken link(s) out of $total_count total."
        echo ""
        echo "To remove broken links, run: sym fix"
    fi
}

# Fixes (removes) all broken symbolic links
fix_links() {
    local link_paths
    link_paths=$(find "$DEST_DIR" -maxdepth 1 -type l 2>/dev/null | sort)

    if [[ -z "$link_paths" ]]; then
        info "No symbolic links found in '$DEST_DIR'."
        return 0
    fi

    local broken_links=()

    # Find broken links
    while IFS= read -r link; do
        local target
        target=$(readlink "$link")

        if [[ ! -e "$target" ]]; then
            broken_links+=("$link")
        fi
    done <<< "$link_paths"

    # Check if any broken links found
    if [[ ${#broken_links[@]} -eq 0 ]]; then
        success "No broken links found!"
        return 0
    fi

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

    # Remove broken links
    local removed_count=0
    for link in "${broken_links[@]}"; do
        if [[ "$DRY_RUN_MODE" == true ]]; then
            info "[DRY RUN] Would remove: $(basename "$link")"
            ((removed_count++))
        else
            if rm "$link" 2>/dev/null; then
                ((removed_count++))
            else
                warn "Failed to remove: $(basename "$link")"
            fi
        fi
    done

    if [[ "$DRY_RUN_MODE" == true ]]; then
        info "[DRY RUN] Would remove $removed_count broken link(s)"
    else
        success "Removed $removed_count broken link(s)!"
    fi
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
            if [[ $# -ne 1 ]]; then
                error_exit "'sym rm' requires exactly one argument (link name)." 4
            fi
            remove_link "$1"
            ;;
        verify|check)
            verify_links
            ;;
        fix|clean)
            fix_links
            ;;
        create|add)
            # sym create [link_name] <source_path>
            if [[ $# -eq 1 ]]; then
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
            elif [[ $# -eq 2 ]]; then
                # Both name and source provided
                create_link "$2" "$1"
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
                fi
            elif [[ $# -eq 1 ]]; then
                # sym <link_name> <source_path>
                create_link "$1" "$command"
            else
                error_exit "Too many arguments.\nUse --help for usage information." 4
            fi
            ;;
    esac

    # Check if DEST_DIR is in PATH (only for create operations)
    if [[ "$command" == "create" || "$command" == "add" ]] || [[ $# -ge 1 ]]; then
        check_path
    fi
}

# Run main function
main "$@"
