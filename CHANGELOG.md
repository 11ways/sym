# Changelog

All notable changes to sym will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-31

### Added

#### Core Features
- Create symbolic links with intuitive command syntax
- List all symbolic links with beautiful formatting
- Show detailed information about individual links
- Remove symbolic links with confirmation prompts
- Verify all links and report broken ones
- Automatically fix (remove) broken links

#### Commands
- `sym create [link_name] <source_path>` - Create new symlinks
- `sym ls [--broken] [--format=FORMAT]` - List all symlinks
- `sym info <link_name>` - Show detailed link information
- `sym rm <link_name>` - Remove symlinks
- `sym verify` - Check all links for validity
- `sym fix` - Remove all broken links

#### Options & Flags
- `-h, --help` - Show comprehensive help message
- `-v, --version` - Display version information
- `-f, --force` - Skip all confirmation prompts
- `-n, --dry-run` - Preview changes without executing them
- `--broken` - Filter to show only broken links
- `--format=FORMAT` - Choose output format (text, json, csv)

#### Output Formats
- **Text**: Human-readable, color-coded output
- **JSON**: Machine-readable format for scripting
- **CSV**: Spreadsheet-friendly export format

#### Display Features
- Color-coded output with smart terminal detection
- Respects `NO_COLOR` environment variable
- Consistent use of → arrow symbols throughout
- Right-aligned link names for easy scanning
- Broken links highlighted in red
- Clear status indicators (✓ for valid, ✗ for broken)

#### Safety & Validation
- Link name validation (prevents path traversal, special characters)
- Source file existence checking
- Confirmation prompts for destructive operations
- Dry-run mode for safe testing
- Force mode for automation and scripting

#### Platform Support
- **macOS**: Full support with BSD stat commands
- **Linux**: Full support with GNU stat commands
- Cross-platform date formatting
- Cross-platform file size calculation

#### File Information
- Creation date/time display
- File size in human-readable format (B, KB, MB, GB)
- File type detection (file, directory, broken)
- Support for `numfmt` when available for better formatting

#### Advanced Features
- Automatic file extension stripping (.sh, .py, .js, etc.)
- PATH validation with helpful warnings
- Custom directory support via `SYM_DIR` environment variable
- Comprehensive error messages with helpful hints
- Meaningful exit codes (0-4) for scripting

#### Developer Features
- Bash strict mode (`set -euo pipefail`)
- All variables properly scoped as local
- Helper functions for common operations
- Modular, maintainable code structure
- Extensive inline documentation

#### Documentation
- Comprehensive README with examples
- Command-line help with usage examples
- MIT License
- Changelog following Keep a Changelog format
- Troubleshooting guide
- Best practices and tips

### Security
- Input sanitization to prevent path traversal
- Validation of link names for dangerous patterns
- Warnings for potentially problematic names
- No execution of user input without validation
- Safe handling of paths with spaces and special characters

### Performance
- Fast execution (milliseconds for all operations)
- Efficient sorting and filtering
- No external dependencies (pure bash)
- Minimal memory footprint
- Optimized file operations

### Developer Experience
- Clear error messages with context
- Helpful hints when operations fail
- Consistent command structure
- Intuitive argument parsing
- Predictable behavior

### User Experience
- Interactive prompts with sensible defaults
- Color-coded output for clarity
- Progress indicators for bulk operations
- Confirmation before destructive actions
- Clear success/failure messages

## [Unreleased]

### Potential Future Features
- Shell completion scripts (bash, zsh, fish)
- Batch operations (create multiple links at once)
- Symlink backup and restore functionality
- Search/filter capabilities
- Edit command to change link destination
- Undo functionality
- Configuration file support
- Link metadata and tagging
- Integration with package managers
- Windows native support (non-WSL)

---

[1.0.0]: https://github.com/11ways/sym/releases/tag/v1.0.0
