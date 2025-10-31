# sym - Symbolic Link Manager

A simple, user-friendly command-line tool for managing symbolic links in `~/.local/bin`.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)

## Features

✨ **Simple & Intuitive** - Easy-to-use commands with helpful prompts
🎨 **Beautiful Output** - Color-coded display with smart formatting
🔍 **Link Management** - List, create, inspect, and remove symbolic links
🛡️ **Safety First** - Validates inputs, confirms destructive operations
🔧 **Maintenance Tools** - Verify and fix broken links automatically
📊 **Multiple Formats** - Export to text, JSON, or CSV
🚀 **Cross-Platform** - Works on both macOS and Linux
⚡ **Fast & Reliable** - Built with bash best practices

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
  - [Creating Links](#creating-links)
  - [Listing Links](#listing-links)
  - [Inspecting Links](#inspecting-links)
  - [Removing Links](#removing-links)
  - [Verifying Links](#verifying-links)
  - [Fixing Broken Links](#fixing-broken-links)
- [Options](#options)
- [Output Formats](#output-formats)
- [Configuration](#configuration)
- [Examples](#examples)
- [Tips & Best Practices](#tips--best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Homebrew (Recommended for macOS)

The easiest way to install sym on macOS is using Homebrew:

```bash
brew install 11ways/sym/sym
```

This automatically installs:
- The `sym` command in your PATH
- The man page (accessible via `man sym`)
- All dependencies

**Verify installation:**
```bash
sym --version
man sym
```

### One-Line Install (Linux & macOS)

For a quick installation on any Unix-like system:

```bash
curl -fsSL https://raw.githubusercontent.com/11ways/sym/main/install.sh | bash
```

**Or safer (inspect the script first):**

```bash
curl -fsSL https://raw.githubusercontent.com/11ways/sym/main/install.sh -o install.sh
less install.sh  # Review the script
bash install.sh
```

This installs to `~/.local/bin` and builds the man page if `pandoc` is available.

**For Linux users:**

Homebrew also works on Linux! Install Homebrew first, then:

```bash
brew install 11ways/sym/sym
```

### Install with Makefile

The Makefile automates installation of both the script and man page:

```bash
# Clone the repository
git clone https://github.com/11ways/sym.git
cd sym

# Install to user directory (no sudo required)
make install-local

# Or install system-wide (requires sudo)
sudo make install
```

**What gets installed:**
- Script: `~/.local/bin/sym` (or `/usr/local/bin/sym` for system-wide)
- Man page: `~/.local/share/man/man1/sym.1.gz` (or `/usr/local/share/man/man1/sym.1.gz`)

**View the man page:**
```bash
# Add to your shell config (~/.bashrc or ~/.zshrc)
export MANPATH="$MANPATH:$HOME/.local/share/man"

# Then view the manual
man sym
```

**Requirements:**
- `pandoc` - for building the man page ([install instructions](https://pandoc.org/installing.html))
- `gzip` - usually pre-installed

### Manual Install

1. Download `sym.sh` to a directory of your choice
2. Make it executable: `chmod +x sym.sh`
3. Add it to your PATH or create a symlink in `~/.local/bin`

### Verify Installation

```bash
sym --version
# Output: sym version 1.0.0
```

### Uninstalling

**Homebrew:**
```bash
brew uninstall sym
```

**Makefile:**
```bash
make uninstall-local  # or make uninstall for system-wide
```

## Quick Start

```bash
# Create a symlink
sym mycommand /path/to/executable

# List all symlinks
sym ls

# Show information about a link
sym info mycommand

# Remove a link
sym rm mycommand
```

## Commands

### Creating Links

Create a symbolic link with an explicit name:

```bash
sym <link_name> <source_path>
```

Or let sym prompt you for a name:

```bash
sym <source_path>
# You'll be prompted to enter a link name
```

**Examples:**

```bash
# Create a link to Sublime Text
sym sublime /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl

# Create a link to a Python script (will prompt for name)
sym ~/scripts/my-tool.py

# Create multiple links
sym docker-compose /usr/local/bin/docker-compose
sym dc /usr/local/bin/docker-compose  # Short alias
```

**Alternative Syntax:**

```bash
sym create <source_path>        # Will prompt for name
sym create <link_name> <source_path>
```

### Listing Links

List all symbolic links:

```bash
sym ls
```

Show only broken links:

```bash
sym ls --broken
```

Output in different formats:

```bash
sym ls --format=json
sym ls --format=csv
```

**Example Output:**

```
Existing symbolic links in '~/.local/bin':

               notch → ~/Repos/wp-notch/notch.sh
                 sym → ~/Repos/sym/sym.sh
              swatch → ~/swatch/swatch.sh
               speak → ~/Repos/simple-speaker/speak.sh
                  km → /Applications/Keyboard Maestro.app/Contents/MacOS/keyboardmaestro
                 yap → ~/repos/slack-extract/yap (Does not exist!)
```

### Inspecting Links

Show detailed information about a specific link:

```bash
sym info <link_name>
```

Or use the shorthand:

```bash
sym <link_name>
```

**Example Output:**

```
  → From:    ~/.local/bin/sublime
  → To:      /Applications/Sublime Text.app/Contents/SharedSupport/bin/subl
  → Created: 2025-10-31 14:23:45
  → Size:    2.4MB
  → Type:    File

To delete:
   sym rm sublime

To change the destination:
   sym sublime <new_destination>
```

### Removing Links

Remove a symbolic link (with confirmation):

```bash
sym rm <link_name>
```

**Aliases:**
```bash
sym remove <link_name>
sym delete <link_name>
```

### Verifying Links

Check all symbolic links and report their status:

```bash
sym verify
```

**Example Output:**

```
Verifying symbolic links...

  ✓ notch → ~/Repos/wp-notch/notch.sh
  ✓ sym → ~/Repos/sym/sym.sh
  ✗ yap → ~/repos/slack-extract/yap (broken)

⚠ Warning: Found 1 broken link(s) out of 3 total.

To remove broken links, run: sym fix
```

**Aliases:**
```bash
sym check
```

### Fixing Broken Links

Automatically remove all broken symbolic links:

```bash
sym fix
```

This will:
1. Find all broken links
2. Show you what will be removed
3. Ask for confirmation
4. Remove the broken links

**Aliases:**
```bash
sym clean
```

## Options

### Global Options

These options work with all commands:

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--version` | `-v` | Show version information |
| `--force` | `-f` | Skip all confirmation prompts |
| `--dry-run` | `-n` | Preview changes without making them |

### Command-Specific Options

**For `sym ls`:**

| Option | Description |
|--------|-------------|
| `--broken` | Show only broken links |
| `--format=FORMAT` | Output format: `text`, `json`, or `csv` |

### Using Options

```bash
# Create without confirmation
sym -f mylink /path/to/file

# Preview what would happen
sym -n mylink /path/to/file

# Force remove without prompt
sym -f rm oldlink

# List broken links in JSON format
sym ls --broken --format=json
```

## Output Formats

### Text (Default)

Human-readable, color-coded output perfect for terminal use.

```bash
sym ls
```

### JSON

Machine-readable format for scripting and integrations:

```bash
sym ls --format=json
```

```json
[
  {
    "name": "sublime",
    "target": "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
    "status": "ok",
    "size": "2.4MB",
    "created": "2025-10-31 14:23:45"
  },
  {
    "name": "oldtool",
    "target": "~/bin/removed-tool",
    "status": "broken",
    "size": "",
    "created": "2025-09-15 10:30:22"
  }
]
```

### CSV

Spreadsheet-friendly format:

```bash
sym ls --format=csv
```

```csv
name,target,status,size,created
sublime,/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl,ok,2.4MB,2025-10-31 14:23:45
oldtool,~/bin/removed-tool,broken,,2025-09-15 10:30:22
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SYM_DIR` | `~/.local/bin` | Directory where symlinks are created |
| `NO_COLOR` | (unset) | Disable colored output |

### Custom Directory

Set a different directory for your symlinks:

```bash
export SYM_DIR="$HOME/bin"
sym mylink /path/to/file
```

### Disable Colors

```bash
# Temporarily
NO_COLOR=1 sym ls

# Permanently (add to ~/.bashrc or ~/.zshrc)
export NO_COLOR=1
```

### Add to PATH

Make sure your symlink directory is in your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:$HOME/.local/bin"
```

## Examples

### Common Use Cases

**Link to GUI Applications (macOS):**

```bash
# Sublime Text
sym sublime /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl

# Visual Studio Code
sym code /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code

# Keyboard Maestro
sym km /Applications/Keyboard\ Maestro.app/Contents/MacOS/keyboardmaestro
```

**Link to Scripts:**

```bash
# Python script
sym mytool ~/scripts/mytool.py

# Shell script
sym backup ~/scripts/backup.sh

# Node.js script
sym deploy ~/projects/deployer/cli.js
```

**Create Short Aliases:**

```bash
# Long command with short alias
sym dc /usr/local/bin/docker-compose
sym k /usr/local/bin/kubectl
sym tf /usr/local/bin/terraform
```

**Batch Cleanup:**

```bash
# Find and fix all broken links
sym verify
sym fix

# Or just fix directly
sym fix -f  # Skip confirmation
```

**Export Link Inventory:**

```bash
# Create a backup of all links
sym ls --format=json > ~/symlinks-backup.json

# Create a CSV for documentation
sym ls --format=csv > ~/symlinks-inventory.csv
```

### Integration with Scripts

**Check if a link exists:**

```bash
if sym info mylink &>/dev/null; then
    echo "Link exists"
else
    echo "Link doesn't exist"
fi
```

**Process all broken links:**

```bash
# Get broken links as JSON
broken_links=$(sym ls --broken --format=json)

# Process with jq
echo "$broken_links" | jq -r '.[].name' | while read link; do
    echo "Broken: $link"
done
```

**Automated cleanup:**

```bash
# Remove all broken links without prompts
sym fix -f
```

## Tips & Best Practices

### Naming Conventions

✅ **Good:**
- Use lowercase names: `mycommand`
- Use hyphens for multi-word names: `my-command`
- Keep names short and memorable: `dc` instead of `docker-compose-wrapper`

❌ **Avoid:**
- Spaces in names: `my command`
- Special characters: `my@command`, `my$cmd`
- Starting with a dot: `.mycommand` (hidden files)

### Organization

- **Keep it simple**: Don't create too many symlinks
- **Use descriptive names**: Others should understand what each link does
- **Regular maintenance**: Run `sym verify` periodically
- **Document custom links**: Keep a README in `~/.local/bin`

### Safety

- **Always review**: Check `sym info` before removing links
- **Use dry-run**: Test with `-n` flag before destructive operations
- **Backup important links**: Export with `sym ls --format=json`
- **Verify after changes**: Run `sym verify` after bulk operations

### Performance

- **Use absolute paths**: Relative paths work but absolute are clearer
- **Check your PATH**: Ensure `~/.local/bin` is in PATH
- **Avoid deep nesting**: Keep source files in accessible locations

## Troubleshooting

### Link not found in PATH

**Problem:** Created a link but can't use it.

**Solution:**
```bash
# Check if directory is in PATH
echo $PATH | grep -q "$HOME/.local/bin" || echo "Not in PATH!"

# Add to PATH (in ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$HOME/.local/bin"

# Reload shell
source ~/.bashrc  # or source ~/.zshrc
```

### Permission denied errors

**Problem:** Can't create or remove links.

**Solution:**
```bash
# Check directory permissions
ls -ld ~/.local/bin

# Fix permissions
chmod 755 ~/.local/bin

# If directory doesn't exist
mkdir -p ~/.local/bin
```

### Colors not working

**Problem:** Output is not colored.

**Solution:**
```bash
# Check if NO_COLOR is set
echo $NO_COLOR

# Unset it
unset NO_COLOR

# Check terminal type
echo $TERM

# If TERM is "dumb", use a better terminal
```

### Broken links after moving files

**Problem:** Links break when source files move.

**Solution:**
```bash
# Find all broken links
sym ls --broken

# Fix by recreating
sym rm oldlink
sym oldlink /new/path/to/file

# Or remove all broken links
sym fix
```

### Script not executable

**Problem:** `sym: command not found`

**Solution:**
```bash
# Make script executable
chmod +x sym.sh

# Or use bash explicitly
bash sym.sh --help
```

## Exit Codes

sym uses meaningful exit codes for scripting:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Not found (file or link doesn't exist) |
| `3` | Permission denied |
| `4` | Invalid argument |

**Example Usage:**

```bash
if sym info mylink; then
    echo "Link exists"
else
    case $? in
        2) echo "Link not found" ;;
        3) echo "Permission denied" ;;
        *) echo "Unknown error" ;;
    esac
fi
```

## Advanced Features

### Custom Destination Directory

```bash
# Set custom directory
export SYM_DIR="$HOME/bin"

# All commands now use ~/bin
sym mylink /path/to/file
```

### Piping Output

```bash
# Count total links
sym ls --format=csv | tail -n +2 | wc -l

# Find links to a specific path
sym ls | grep "/Applications"

# Export only broken links
sym ls --broken --format=json > broken-links.json
```

### Automation

**Weekly maintenance script:**

```bash
#!/bin/bash
# ~/.local/scripts/sym-maintenance.sh

echo "Checking symbolic links..."
sym verify

echo "Cleaning up broken links..."
sym fix -f

echo "Exporting inventory..."
sym ls --format=json > ~/Dropbox/symlinks-backup.json

echo "Done!"
```

**Add to cron:**

```bash
# Run every Sunday at 9 AM
0 9 * * 0 /bin/bash ~/.local/scripts/sym-maintenance.sh
```

## Platform Compatibility

### macOS

✅ Fully supported
- Uses BSD stat commands
- Handles .app bundles correctly
- Supports long paths with spaces

### Linux

✅ Fully supported
- Uses GNU stat commands
- Works with all distributions
- Supports systemd paths

### Windows (WSL)

✅ Supported via WSL (Windows Subsystem for Linux)
- Use Linux commands in WSL
- Can link to Windows executables
- Requires proper PATH configuration

## Performance Notes

- **Fast operations**: All commands run in milliseconds
- **No dependencies**: Pure bash, no external tools required
- **Efficient sorting**: Uses native bash sorting
- **Optional features**: `numfmt` used for better file sizes if available

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs**: Open an issue on GitHub
2. **Suggest features**: Share your ideas in discussions
3. **Submit pull requests**: Fix bugs or add features
4. **Improve documentation**: Help make the docs better
5. **Share feedback**: Let us know how you use sym

### Development

```bash
# Clone the repo
git clone https://github.com/roelvangils/sym.git
cd sym

# Make changes
vim sym.sh

# Test your changes
./sym.sh --version
./sym.sh ls

# Run with dry-run to test safely
./sym.sh -n mytest /path/to/file
```

### Code Style

- Use `bash` (not `sh`)
- Follow existing formatting
- Add comments for complex logic
- Use meaningful variable names
- Handle errors gracefully

## License

MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Roel van Gils

## Acknowledgments

- Inspired by the need for simple symlink management
- Built with love for the command-line
- Thanks to all contributors and users

## Support

- **Issues**: https://github.com/roelvangils/sym/issues
- **Discussions**: https://github.com/roelvangils/sym/discussions
- **Email**: your-email@example.com

---

**Made with ❤️ by [Roel van Gils](https://github.com/roelvangils)**

If you find this tool useful, consider giving it a ⭐ on GitHub!
