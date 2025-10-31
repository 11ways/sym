# sym Examples

Real-world examples of using sym for common tasks.

## Table of Contents

- [Development Tools](#development-tools)
- [GUI Applications (macOS)](#gui-applications-macos)
- [Command Shortcuts](#command-shortcuts)
- [Script Management](#script-management)
- [Automation & Scripting](#automation--scripting)
- [Maintenance Workflows](#maintenance-workflows)

## Development Tools

### Node.js Global Packages

```bash
# Link npm global binaries
sym tsc /usr/local/lib/node_modules/typescript/bin/tsc
sym eslint /usr/local/lib/node_modules/eslint/bin/eslint.js
sym prettier /usr/local/lib/node_modules/prettier/bin-prettier.js

# Verify they work
tsc --version
eslint --version
```

### Python Virtual Environments

```bash
# Create shortcuts to Python tools
sym python3.11 /usr/local/bin/python3.11
sym pip3.11 /usr/local/bin/pip3.11

# Link to project-specific tools
sym myproject-serve ~/projects/myproject/venv/bin/python
```

### Docker Tools

```bash
# Create short aliases for Docker commands
sym dc /usr/local/bin/docker-compose
sym k /usr/local/bin/kubectl
sym tf /usr/local/bin/terraform

# Now use short commands
dc up -d
k get pods
tf plan
```

### Version Managers

```bash
# Link to specific versions
sym node16 ~/.nvm/versions/node/v16.20.0/bin/node
sym node18 ~/.nvm/versions/node/v18.17.0/bin/node
sym node20 ~/.nvm/versions/node/v20.5.0/bin/node

# Switch between versions easily
node16 --version
node18 --version
```

## GUI Applications (macOS)

### Code Editors

```bash
# Sublime Text
sym subl /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl
sym sublime /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl

# VS Code
sym code /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code

# Atom
sym atom /Applications/Atom.app/Contents/Resources/app/atom.sh

# Now open files easily
subl myfile.txt
code myproject/
```

### Productivity Apps

```bash
# Keyboard Maestro
sym km /Applications/Keyboard\ Maestro.app/Contents/MacOS/keyboardmaestro

# Alfred
sym alfred "/Applications/Alfred 5.app/Contents/MacOS/Alfred"

# Rectangle (window manager)
sym rectangle /Applications/Rectangle.app/Contents/MacOS/Rectangle
```

### Design Tools

```bash
# Sketch
sym sketch /Applications/Sketch.app/Contents/MacOS/Sketch

# Figma
sym figma /Applications/Figma.app/Contents/MacOS/Figma
```

### Browsers

```bash
# Chrome
sym chrome "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Firefox
sym firefox /Applications/Firefox.app/Contents/MacOS/firefox

# Safari
sym safari /Applications/Safari.app/Contents/MacOS/Safari

# Now open URLs from command line
chrome https://github.com
```

## Command Shortcuts

### Git Shortcuts

```bash
# Create git alias commands
cat > ~/scripts/git-shortcuts.sh << 'EOF'
#!/bin/bash
case "$(basename "$0")" in
    "gs") git status "$@" ;;
    "ga") git add "$@" ;;
    "gc") git commit "$@" ;;
    "gp") git push "$@" ;;
    "gl") git pull "$@" ;;
    "gd") git diff "$@" ;;
esac
EOF

chmod +x ~/scripts/git-shortcuts.sh

# Create symlinks for each command
sym gs ~/scripts/git-shortcuts.sh
sym ga ~/scripts/git-shortcuts.sh
sym gc ~/scripts/git-shortcuts.sh
sym gp ~/scripts/git-shortcuts.sh
sym gl ~/scripts/git-shortcuts.sh
sym gd ~/scripts/git-shortcuts.sh

# Now use shortcuts
gs          # git status
ga .        # git add .
gc -m "msg" # git commit -m "msg"
```

### Common Commands

```bash
# Create shortcuts for long commands
echo '#!/bin/bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"' > ~/scripts/dps.sh
chmod +x ~/scripts/dps.sh
sym dps ~/scripts/dps.sh

# Now use: dps
```

## Script Management

### Personal Scripts

```bash
# Create a scripts directory
mkdir -p ~/scripts

# Add your scripts
cat > ~/scripts/backup.sh << 'EOF'
#!/bin/bash
rsync -av ~/Documents /backup/
EOF
chmod +x ~/scripts/backup.sh

# Create links for easy access
sym backup ~/scripts/backup.sh

# Run from anywhere
backup
```

### Project Tools

```bash
# Link project-specific tools
sym myproject-deploy ~/projects/myproject/bin/deploy.sh
sym myproject-test ~/projects/myproject/bin/run-tests.sh
sym myproject-build ~/projects/myproject/bin/build.sh

# Access from any directory
myproject-deploy production
myproject-test unit
```

### Maintenance Scripts

```bash
# System cleanup
cat > ~/scripts/cleanup.sh << 'EOF'
#!/bin/bash
echo "Cleaning up..."
brew cleanup
npm cache clean --force
docker system prune -f
echo "Done!"
EOF
chmod +x ~/scripts/cleanup.sh
sym cleanup ~/scripts/cleanup.sh

# Weekly maintenance
cat > ~/scripts/update-all.sh << 'EOF'
#!/bin/bash
echo "Updating all packages..."
brew update && brew upgrade
npm update -g
echo "Done!"
EOF
chmod +x ~/scripts/update-all.sh
sym update-all ~/scripts/update-all.sh
```

## Automation & Scripting

### Batch Link Creation

```bash
#!/bin/bash
# create-dev-links.sh - Set up all development tools

declare -A links=(
    ["node"]="/usr/local/bin/node"
    ["npm"]="/usr/local/bin/npm"
    ["python3"]="/usr/local/bin/python3"
    ["pip3"]="/usr/local/bin/pip3"
    ["code"]="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    ["subl"]="/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
)

for name in "${!links[@]}"; do
    sym -f "$name" "${links[$name]}"
done

echo "Development environment links created!"
```

### Environment Setup

```bash
#!/bin/bash
# setup-machine.sh - Set up a new machine

# Install tools first
brew install node python3 docker

# Create all necessary links
sym node /usr/local/bin/node
sym npm /usr/local/bin/npm
sym python3 /usr/local/bin/python3
sym docker /usr/local/bin/docker

# Verify everything
sym verify

echo "Machine setup complete!"
```

### Link Backup & Restore

```bash
# Backup all links
sym ls --format=json > ~/Dropbox/symlinks-backup.json

# Restore on another machine
cat ~/Dropbox/symlinks-backup.json | jq -r '.[] | "\(.name) \(.target)"' | while read name target; do
    sym -f "$name" "$target" 2>/dev/null || echo "Skipped: $name"
done
```

### Monitoring Script

```bash
#!/bin/bash
# check-links.sh - Monitor link health

echo "Checking symbolic links..."
broken=$(sym ls --broken --format=json)
count=$(echo "$broken" | jq length)

if [[ $count -gt 0 ]]; then
    echo "⚠️  Found $count broken link(s):"
    echo "$broken" | jq -r '.[].name'

    # Send notification (macOS)
    osascript -e "display notification \"Found $count broken links\" with title \"sym\""

    exit 1
else
    echo "✅ All links are healthy!"
    exit 0
fi
```

## Maintenance Workflows

### Weekly Maintenance

```bash
#!/bin/bash
# weekly-maintenance.sh

echo "=== Weekly sym Maintenance ==="
echo ""

echo "1. Verifying all links..."
sym verify

echo ""
echo "2. Finding broken links..."
broken=$(sym ls --broken --format=csv | tail -n +2 | wc -l)
echo "Found $broken broken link(s)"

if [[ $broken -gt 0 ]]; then
    echo ""
    echo "3. Cleaning up broken links..."
    sym fix -f
fi

echo ""
echo "4. Backing up link configuration..."
sym ls --format=json > ~/Dropbox/symlinks-backup-$(date +%Y%m%d).json

echo ""
echo "5. Generating report..."
sym ls --format=csv > ~/Documents/symlinks-report-$(date +%Y%m%d).csv

echo ""
echo "✅ Maintenance complete!"
```

Add to cron:
```bash
# Run every Sunday at 9 AM
0 9 * * 0 /bin/bash ~/scripts/weekly-maintenance.sh
```

### Before System Upgrade

```bash
#!/bin/bash
# pre-upgrade-backup.sh

echo "Creating pre-upgrade backup..."

# Backup all symlinks
sym ls --format=json > ~/backup-symlinks-pre-upgrade-$(date +%Y%m%d).json

# List all tools
sym ls > ~/backup-symlinks-list-$(date +%Y%m%d).txt

# Verify all links work
sym verify > ~/backup-symlinks-verify-$(date +%Y%m%d).txt

echo "Backup complete! Files saved to ~/"
```

### New Project Setup

```bash
#!/bin/bash
# setup-project.sh <project-name>

PROJECT_NAME="$1"
PROJECT_DIR="$HOME/projects/$PROJECT_NAME"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: setup-project.sh <project-name>"
    exit 1
fi

# Create project structure
mkdir -p "$PROJECT_DIR"/{bin,src,tests}

# Create project scripts
cat > "$PROJECT_DIR/bin/dev.sh" << 'EOF'
#!/bin/bash
echo "Starting dev server..."
EOF

cat > "$PROJECT_DIR/bin/test.sh" << 'EOF'
#!/bin/bash
echo "Running tests..."
EOF

chmod +x "$PROJECT_DIR/bin"/*.sh

# Create symlinks
sym "$PROJECT_NAME-dev" "$PROJECT_DIR/bin/dev.sh"
sym "$PROJECT_NAME-test" "$PROJECT_DIR/bin/test.sh"

echo "✅ Project $PROJECT_NAME set up!"
echo "   Start dev: $PROJECT_NAME-dev"
echo "   Run tests: $PROJECT_NAME-test"
```

### Team Onboarding

```bash
#!/bin/bash
# onboard-developer.sh

echo "🎉 Welcome to the team!"
echo ""
echo "Setting up your development environment..."

# Required tools
REQUIRED_TOOLS=(
    "node::/usr/local/bin/node"
    "npm::/usr/local/bin/npm"
    "docker::/usr/local/bin/docker"
    "code::/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
)

for tool in "${REQUIRED_TOOLS[@]}"; do
    name="${tool%%::*}"
    path="${tool##*::}"

    if [[ -e "$path" ]]; then
        sym -f "$name" "$path"
        echo "✓ Linked $name"
    else
        echo "✗ $name not found at $path"
    fi
done

# Project-specific tools
sym deploy ~/company/tools/deploy.sh
sym release ~/company/tools/release.sh
sym monitor ~/company/tools/monitor.sh

echo ""
echo "✅ Environment setup complete!"
echo "Run 'sym ls' to see all available commands"
```

## Advanced Use Cases

### Dynamic Link Management

```bash
#!/bin/bash
# switch-environment.sh <env>

ENV="$1"

case "$ENV" in
    dev)
        sym -f db-connect ~/scripts/connect-dev-db.sh
        sym -f api ~/projects/api/dev-server.sh
        echo "Switched to DEV environment"
        ;;
    staging)
        sym -f db-connect ~/scripts/connect-staging-db.sh
        sym -f api ~/projects/api/staging-server.sh
        echo "Switched to STAGING environment"
        ;;
    prod)
        sym -f db-connect ~/scripts/connect-prod-db.sh
        sym -f api ~/projects/api/prod-server.sh
        echo "Switched to PROD environment"
        ;;
    *)
        echo "Usage: switch-environment.sh <dev|staging|prod>"
        exit 1
        ;;
esac
```

### Link Health Dashboard

```bash
#!/bin/bash
# sym-dashboard.sh

echo "╔══════════════════════════════════╗"
echo "║     sym Link Dashboard          ║"
echo "╚══════════════════════════════════╝"
echo ""

# Get statistics
total=$(sym ls --format=json | jq length)
broken=$(sym ls --broken --format=json | jq length)
healthy=$((total - broken))

# Calculate percentage
if [[ $total -gt 0 ]]; then
    health_pct=$((healthy * 100 / total))
else
    health_pct=0
fi

echo "📊 Statistics:"
echo "   Total links:   $total"
echo "   Healthy:       $healthy"
echo "   Broken:        $broken"
echo "   Health:        $health_pct%"
echo ""

if [[ $broken -gt 0 ]]; then
    echo "⚠️  Broken Links:"
    sym ls --broken --format=json | jq -r '.[] | "   - \(.name) → \(.target)"'
    echo ""
fi

echo "📅 Last Updated: $(date)"
```

## Tips & Tricks

### Quick Audit

```bash
# See what's taking up space
sym ls --format=json | jq -r '.[] | select(.size != "") | "\(.size)\t\(.name)"' | sort -h

# Find old links
sym ls --format=json | jq -r '.[] | "\(.created)\t\(.name)"' | sort

# Export to spreadsheet
sym ls --format=csv | open -f -a "Microsoft Excel"
```

### Integration with Other Tools

```bash
# Use with fzf for fuzzy finding
sym ls | fzf | awk '{print $1}' | xargs sym info

# Pipe broken links to another command
sym ls --broken --format=json | jq -r '.[].name' | xargs -I {} echo "Remove: {}"
```

---

Have more examples? [Contribute them](CONTRIBUTING.md) to help others!
