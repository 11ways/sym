# Contributing to sym

Thank you for considering contributing to sym! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

This project follows a simple code of conduct:

- Be respectful and inclusive
- Be patient with newcomers
- Focus on constructive feedback
- Assume good intentions

## How Can I Contribute?

### Reporting Bugs

Found a bug? Please open an issue with:

- **Clear title**: Describe the issue briefly
- **Steps to reproduce**: List exact steps to trigger the bug
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Environment**: OS, bash version, terminal
- **Screenshots**: If applicable

**Example:**

```markdown
## Bug: Broken links not detected on macOS Sonoma

**Steps to reproduce:**
1. Create a link: `sym test ~/nonexistent-file`
2. Run: `sym verify`

**Expected:** Should report broken link
**Actual:** Shows as valid

**Environment:**
- macOS 14.1 Sonoma
- bash 3.2.57
- Terminal.app
```

### Suggesting Features

Have an idea? Open an issue with:

- **Use case**: Why is this feature needed?
- **Proposed solution**: How should it work?
- **Alternatives**: What other approaches were considered?
- **Examples**: Show how it would be used

### Contributing Code

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test thoroughly**
5. **Commit with clear messages**
6. **Push to your fork**
7. **Open a Pull Request**

### Improving Documentation

Documentation improvements are always welcome:

- Fix typos and grammar
- Clarify confusing sections
- Add more examples
- Improve troubleshooting guides
- Translate to other languages

## Development Setup

### Prerequisites

- bash 4.0 or higher (3.2+ works with limitations)
- git
- A Unix-like environment (macOS, Linux, WSL)

### Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/sym.git
cd sym

# Make the script executable
chmod +x sym.sh

# Test it works
./sym.sh --version
```

### Project Structure

```
sym/
├── sym.sh              # Main script
├── README.md           # User documentation
├── CHANGELOG.md        # Version history
├── CONTRIBUTING.md     # This file
├── LICENSE             # MIT License
└── tests/              # Test files (future)
```

## Coding Standards

### Bash Style Guide

#### Shebang
```bash
#!/usr/bin/env bash
```

#### Strict Mode
```bash
set -euo pipefail
```

#### Variables

**Constants:** Uppercase with readonly
```bash
readonly VERSION="1.0.0"
readonly DEST_DIR="$HOME/.local/bin"
```

**Local variables:** Lowercase
```bash
local link_name="$1"
local source_path="$2"
```

**Global state:** Uppercase (avoid when possible)
```bash
FORCE_MODE=false
DRY_RUN_MODE=false
```

#### Functions

**Format:**
```bash
# Brief description of what the function does
function_name() {
    local param1="$1"
    local param2="$2"

    # Function body

    return 0
}
```

**Naming:**
- Use snake_case: `validate_link_name`
- Be descriptive: `get_file_size` not `getsize`
- Use verbs: `create_link`, `remove_link`, `show_info`

#### Quoting

**Always quote variables:**
```bash
# Good
if [[ -e "$file_path" ]]; then

# Bad
if [[ -e $file_path ]]; then
```

**Exception:** When intentional word splitting is needed
```bash
local options
options="--verbose --color"
command $options  # Intentional word splitting
```

#### Conditionals

**Use [[  ]] for conditions:**
```bash
# Good
if [[ "$var" == "value" ]]; then

# Avoid
if [ "$var" = "value" ]; then
```

**Pattern matching:**
```bash
if [[ "$var" =~ ^[0-9]+$ ]]; then
    echo "Number"
fi
```

#### Error Handling

**Use error_exit for fatal errors:**
```bash
if [[ ! -e "$source" ]]; then
    error_exit "Source not found: $source" 2
fi
```

**Use warn for non-fatal issues:**
```bash
if [[ "$name" =~ [[:space:]] ]]; then
    warn "Link name contains spaces"
fi
```

#### Comments

**Use comments liberally:**
```bash
# Check if the target exists before resolving
if [[ -e "$target" ]]; then
    # Resolve to absolute path for consistency
    target=$(realpath "$target" 2>/dev/null || echo "$target")
fi
```

**Document complex logic:**
```bash
# Strip common file extensions (.sh, .py, .js, etc.)
# This provides a sensible default name for the user
strip_extensions() {
    local name="$1"
    echo "$name" | sed -E 's/\.(sh|bash|zsh|py|rb|js|pl|command|app|bin|exe)$//'
}
```

### Code Organization

#### Function Order
1. Utility functions (error handling, validation)
2. Helper functions (file operations, formatting)
3. Core functions (create, remove, list, etc.)
4. Main script logic

#### Grouping
```bash
# === UTILITY FUNCTIONS ===

# === HELPER FUNCTIONS ===

# === CORE FUNCTIONS ===

# === MAIN SCRIPT LOGIC ===
```

### Color Usage

**Be consistent:**
```bash
C_RED='\033[0;31m'      # Errors, broken links
C_GREEN='\033[0;32m'    # Success, valid links
C_YELLOW='\033[0;33m'   # Warnings
C_BLUE='\033[0;34m'     # Info, paths
C_WHITE='\033[1;37m'    # Normal text
C_GRAY='\033[1;30m'     # Muted text (arrows, etc.)
```

**Always check for color support:**
```bash
if [[ -v NO_COLOR ]] || [[ ! -t 1 ]]; then
    # Disable colors
fi
```

## Testing

### Manual Testing

Before submitting changes, test:

1. **Basic operations:**
   ```bash
   ./sym.sh ls
   ./sym.sh create testlink /bin/ls
   ./sym.sh info testlink
   ./sym.sh rm testlink
   ```

2. **Edge cases:**
   ```bash
   # Non-existent files
   ./sym.sh badfile /path/that/doesnt/exist

   # Special characters
   ./sym.sh "link with spaces" /bin/ls
   ./sym.sh .hiddenlink /bin/ls

   # Broken links
   ./sym.sh broken /tmp/deleted-file
   rm /tmp/deleted-file
   ./sym.sh verify
   ```

3. **Options:**
   ```bash
   ./sym.sh --help
   ./sym.sh --version
   ./sym.sh -f create forcedlink /bin/ls
   ./sym.sh -n create dryrunlink /bin/ls
   ```

4. **Output formats:**
   ```bash
   ./sym.sh ls --format=json
   ./sym.sh ls --format=csv
   ./sym.sh ls --broken
   ```

5. **Cross-platform** (if possible):
   - Test on macOS
   - Test on Linux
   - Test in different terminals

### Automated Testing (Future)

We plan to add automated tests. Until then:

- Test manually before submitting
- Document test cases in PR description
- Include examples of new features working

## Submitting Changes

### Commit Messages

Use clear, descriptive commit messages:

**Format:**
```
type: Brief description (50 chars max)

Detailed explanation of what changed and why.
Can span multiple lines.

Fixes #123
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style/formatting
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance tasks

**Examples:**

```
feat: Add --broken flag to ls command

Allows users to filter and show only broken symbolic links.
Useful for quickly identifying links that need attention.

Usage: sym ls --broken

Closes #45
```

```
fix: Correct file size calculation on Linux

The stat command format was incorrect for GNU stat,
causing file sizes to display as empty on Linux systems.

Fixed by using -c flag instead of -f for GNU stat.

Fixes #67
```

### Pull Request Process

1. **Update documentation** if needed
2. **Update CHANGELOG.md** with your changes
3. **Ensure code follows style guide**
4. **Test on your platform**
5. **Create PR with clear description:**

**PR Template:**
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Code refactoring

## Testing
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Manual testing completed
- [ ] Edge cases considered

## Checklist
- [ ] Code follows style guide
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No breaking changes (or documented)

## Related Issues
Fixes #123
Related to #456
```

### Review Process

- Maintainer will review within a week
- May request changes or clarifications
- Once approved, will be merged
- Be patient and responsive to feedback

## Best Practices

### Do's ✅

- Write clear, self-documenting code
- Add comments for complex logic
- Handle errors gracefully
- Test edge cases
- Keep functions focused and small
- Use meaningful variable names
- Follow existing patterns
- Update documentation

### Don'ts ❌

- Don't use global variables unnecessarily
- Don't ignore errors
- Don't make breaking changes without discussion
- Don't submit untested code
- Don't mix multiple concerns in one PR
- Don't use bash-isms without checking compatibility
- Don't hard-code paths or values

## Questions?

- Open an issue for questions
- Tag with `question` label
- Check existing issues first
- Be specific about what you need help with

## Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Mentioned in release notes
- Credited in README.md (for significant contributions)

Thank you for contributing to sym! 🎉
