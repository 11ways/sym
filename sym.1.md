---
title: SYM
section: 1
header: User Manual
footer: sym 1.1.0
date: April 2026
---

# NAME

sym - symbolic link manager for ~/.local/bin

# SYNOPSIS

**sym** [*OPTIONS*] *command* [*ARGS*...]

**sym** [*OPTIONS*] [*link_name*] *source_path*

# DESCRIPTION

**sym** is a user-friendly command-line tool for managing symbolic links in **~/.local/bin**. It provides a simple interface for creating, listing, inspecting, and removing symbolic links, with safety features and multiple output formats.

The tool is designed to help developers and system administrators easily manage command-line utilities by creating symbolic links in a directory that's typically in the user's PATH.

# OPTIONS

**-h**, **--help**
:   Show help message and exit.

**-v**, **--version**
:   Show version information and exit.

**-f**, **--force**
:   Skip all confirmation prompts. Useful for automation and scripting.

**-n**, **--dry-run**
:   Preview what would be done without actually making any changes. Shows intended operations without executing them.

# COMMANDS

## ls [--broken] [--name=*GLOB*] [--format=*FORMAT*]

Lists all symbolic links in the configured directory.

**--broken**
:   Show only broken links (links pointing to non-existent targets).

**--name**=*GLOB*
:   Filter by a shell glob against the link name (e.g. **--name='my\*'**).

**--format**=*FORMAT*
:   Output format: **text** (default), **json**, or **csv**.

## info *link_name*

Shows detailed information about a specific symbolic link, including:

- Link location and target
- Creation date
- File size (if target exists)
- Target type (file, directory, or broken)
- Suggested commands for modification

Aliases: **show**

## rm *link_name* | --match *GLOB*

Removes a symbolic link from the configured directory. Prompts for confirmation before deletion unless **--force** is specified.

With **--match** *GLOB*, removes every link whose name matches the glob after a single confirmation. The operation is recorded in the undo journal as a bulk op.

Aliases: **remove**, **delete**

## verify

Checks all symbolic links and reports their status. Shows:

- Valid links with checkmarks
- Broken links with warning indicators
- Summary statistics
- Suggestions for fixing broken links

Exits non-zero (status 1) when at least one broken link is found, so CI
pipelines and pre-commit hooks can rely on its status.

Aliases: **check**

## fix

Automatically removes all broken symbolic links after showing what will be removed and asking for confirmation (unless **--force** is specified).

Aliases: **clean**

## create [*link_name*] *source_path* | --from *DIR*

Creates a new symbolic link. If *link_name* is omitted, you will be prompted to enter one. The tool automatically suggests a name based on the source filename with common extensions removed.

Replacement of an existing link is atomic: **sym** creates a temporary symlink alongside the destination and uses **rename(2)** to put it in place, so there is never a window where the destination is missing.

With **--from** *DIR*, batch-creates links for every regular file at the top level of *DIR* (dotfiles and directories are skipped; an identical existing link is treated as idempotent).

You can also use the shorthand: **sym** [*link_name*] *source_path*

## edit *link_name* *new_target*

Atomically retargets an existing symbolic link to point at *new_target*. The previous target is recorded in the undo journal.

Aliases: **retarget**

## completion *bash|zsh|fish*

Prints a shell completion script to stdout. Install by redirecting to a file the shell loads automatically, or source it directly from your shell rc.

## undo

Reverses the most recent mutating operation (create, rm, edit, fix, batch create/remove, or snapshot restore). Single-level history only — each new mutating command overwrites the journal.

## snapshot *save* [*file*] | *list* | *restore* *file*

**save**
:   Writes the full state of the link directory to a JSON file. With no argument, writes to **$SYM_STATE_DIR/snapshots/YYYYMMDD-HHMMSS.json**.

**list**
:   Lists snapshot files in the default directory.

**restore** *file*
:   Computes the delta between current state and the snapshot (removes, creates, retargets), confirms, and applies atomically. The pre-restore state is recorded so **sym undo** reverses the restore.

## *link_name*

When called with just a link name, shows information about that link if it exists, or prompts to create it if it doesn't.

# OUTPUT FORMATS

**text** (default)
:   Human-readable, color-coded output optimized for terminal display. Includes visual indicators and aligned columns.

**json**
:   Machine-readable JSON format suitable for scripting and integration with other tools. Each link is represented as an object with properties: name, target, status, size, and created.

**csv**
:   Comma-separated values format suitable for importing into spreadsheets or databases. Includes headers: name, target, status, size, created.

# EXAMPLES

Create a symlink named 'sublime' pointing to Sublime Text:

    $ sym sublime /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl

List all symbolic links:

    $ sym ls

Show only broken links:

    $ sym ls --broken

Export links to JSON:

    $ sym ls --format=json > links.json

Show information about a link:

    $ sym info sublime

Remove a link:

    $ sym rm sublime

Create a link without confirmation:

    $ sym -f mylink /path/to/file

Preview what would be created:

    $ sym -n testlink /usr/bin/test

Verify all links are valid:

    $ sym verify

Remove all broken links:

    $ sym fix

Create multiple short aliases:

    $ sym dc /usr/local/bin/docker-compose
    $ sym k /usr/local/bin/kubectl
    $ sym tf /usr/local/bin/terraform

# ENVIRONMENT

**SYM_DIR**
:   Directory where symbolic links are created. Default: **~/.local/bin**

    Example:

        $ export SYM_DIR="$HOME/bin"
        $ sym mylink /path/to/file

**SYM_STATE_DIR**
:   Directory for the undo journal and snapshot files. Default: **~/.local/share/sym**

    Example:

        $ export SYM_STATE_DIR="$HOME/var/sym-state"
        $ sym undo

**NO_COLOR**
:   When set (to any value), disables colored output. Useful for scripts or when output is redirected.

    Example:

        $ NO_COLOR=1 sym ls

# EXIT STATUS

**0**
:   Success - operation completed successfully.

**1**
:   General error - an unspecified error occurred.

**2**
:   Not found - the specified file or link does not exist.

**3**
:   Permission denied - insufficient permissions to perform the operation.

**4**
:   Invalid argument - invalid command-line argument or option.

# FILES

**~/.local/bin**
:   Default directory where symbolic links are created and managed. This directory should be in your PATH for links to be accessible.

# CONFIGURATION

**sym** requires no configuration files. All settings are controlled through environment variables or command-line options.

Ensure **~/.local/bin** (or your custom **SYM_DIR**) is in your PATH:

    # Add to ~/.bashrc or ~/.zshrc
    export PATH="$PATH:$HOME/.local/bin"

# FEATURES

**Safety First**
:   Validates inputs, confirms destructive operations, and provides dry-run mode for safe testing.

**Cross-Platform**
:   Works on both macOS and Linux with appropriate platform-specific adaptations.

**Smart Defaults**
:   Automatically suggests link names by removing common file extensions (.sh, .py, .js, etc.).

**Visual Feedback**
:   Color-coded output with status indicators (✓ for valid, ✗ for broken) and aligned formatting.

**Machine-Readable**
:   JSON and CSV output formats for integration with scripts and other tools.

**Maintenance Tools**
:   Built-in verification and automatic repair of broken links.

# TIPS

**Naming Conventions**
:   Use lowercase names (mycommand), hyphens for multi-word names (my-command), and keep names short and memorable.

**Regular Maintenance**
:   Run **sym verify** periodically to check for broken links.

**Backup Links**
:   Export your links regularly: **sym ls --format=json > ~/symlinks-backup.json**

**Tab Completion**
:   Link names appear in shell tab completion since they're in your PATH.

# DIAGNOSTICS

If links aren't working after creation:

1. Verify the directory is in PATH:

       $ echo $PATH | grep -o "$HOME/.local/bin"

2. If missing, add to your shell configuration:

       $ echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
       $ source ~/.bashrc

3. Verify the link exists:

       $ ls -la ~/.local/bin/

4. Check link target:

       $ sym info linkname

If colors aren't displaying:

1. Check if NO_COLOR is set: **echo $NO_COLOR**
2. Verify terminal supports colors: **echo $TERM**
3. Ensure output isn't redirected to a file

# LIMITATIONS

- Only manages links in a single directory (configurable via **SYM_DIR**)
- Requires bash 4.0+ (3.2+ works with some limitations)
- Color output requires ANSI-compatible terminal
- File size calculation requires **stat** command

# BUGS

Report bugs at: <https://github.com/11ways/sym/issues>

# SEE ALSO

**ln**(1), **readlink**(1), **realpath**(1), **find**(1)

# AUTHOR

Written by Roel Van Gils.

# COPYRIGHT

Copyright © 2025-2026 Roel Van Gils. License: MIT

This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

# NOTES

For the latest documentation, examples, and updates, visit:
<https://github.com/11ways/sym>

To contribute to **sym** or report issues, see:
<https://github.com/11ways/sym/blob/main/CONTRIBUTING.md>
