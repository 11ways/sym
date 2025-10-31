# Makefile for sym - Symbolic Link Manager
# Version: 1.0.0

# === CONFIGURATION ===
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1

# Installation directories (can be overridden with SYM_DIR)
INSTALL_BIN = $(HOME)/.local/bin
INSTALL_MAN = $(HOME)/.local/share/man/man1

# Source files
SCRIPT = sym.sh
MANPAGE_SRC = sym.1.md
MANPAGE = sym.1
MANPAGE_GZ = sym.1.gz

# Tools
PANDOC = pandoc
GZIP = gzip
INSTALL = install
RM = rm -f
MKDIR = mkdir -p

# Colors for output
COLOR_RESET = \033[0m
COLOR_BLUE = \033[0;34m
COLOR_GREEN = \033[0;32m
COLOR_YELLOW = \033[0;33m

# === TARGETS ===

.PHONY: all build man install install-local uninstall uninstall-local clean test help check-pandoc

# Default target
all: build

# Build the man page from markdown
man: check-pandoc $(MANPAGE_GZ)
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Man page built successfully"

$(MANPAGE): $(MANPAGE_SRC)
	@echo "$(COLOR_BLUE)Building man page from markdown...$(COLOR_RESET)"
	@$(PANDOC) --standalone --from markdown --to man $(MANPAGE_SRC) -o $(MANPAGE)

$(MANPAGE_GZ): $(MANPAGE)
	@echo "$(COLOR_BLUE)Compressing man page...$(COLOR_RESET)"
	@$(GZIP) -9 -c $(MANPAGE) > $(MANPAGE_GZ)

# Build target (same as man)
build: man

# Install system-wide (requires sudo)
install: man
	@echo "$(COLOR_BLUE)Installing sym system-wide (requires sudo)...$(COLOR_RESET)"
	@sudo $(MKDIR) $(BINDIR)
	@sudo $(INSTALL) -m 755 $(SCRIPT) $(BINDIR)/sym
	@sudo $(MKDIR) $(MANDIR)
	@sudo $(INSTALL) -m 644 $(MANPAGE_GZ) $(MANDIR)/$(MANPAGE_GZ)
	@sudo mandb 2>/dev/null || true
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Installed to $(BINDIR)/sym"
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Man page installed to $(MANDIR)/$(MANPAGE_GZ)"
	@echo ""
	@echo "You can now use: sym --help"
	@echo "Or read the manual: man sym"

# Install to user's local directory (no sudo required)
install-local: man
	@echo "$(COLOR_BLUE)Installing sym locally to $(INSTALL_BIN)...$(COLOR_RESET)"
	@$(MKDIR) $(INSTALL_BIN)
	@$(INSTALL) -m 755 $(SCRIPT) $(INSTALL_BIN)/sym
	@$(MKDIR) $(INSTALL_MAN)
	@$(INSTALL) -m 644 $(MANPAGE_GZ) $(INSTALL_MAN)/$(MANPAGE_GZ)
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Installed to $(INSTALL_BIN)/sym"
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Man page installed to $(INSTALL_MAN)/$(MANPAGE_GZ)"
	@echo ""
	@echo "$(COLOR_YELLOW)Note:$(COLOR_RESET) Make sure $(INSTALL_BIN) is in your PATH:"
	@echo "  export PATH=\"\$$PATH:$(INSTALL_BIN)\""
	@echo ""
	@echo "$(COLOR_YELLOW)Note:$(COLOR_RESET) To enable 'man sym', add to MANPATH:"
	@echo "  export MANPATH=\"\$$MANPATH:$(HOME)/.local/share/man\""
	@echo ""
	@echo "You can now use: sym --help"
	@echo "Or read the manual: man sym"

# Uninstall system-wide
uninstall:
	@echo "$(COLOR_BLUE)Uninstalling sym (system-wide)...$(COLOR_RESET)"
	@sudo $(RM) $(BINDIR)/sym
	@sudo $(RM) $(MANDIR)/$(MANPAGE_GZ)
	@sudo mandb 2>/dev/null || true
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Uninstalled"

# Uninstall from user's local directory
uninstall-local:
	@echo "$(COLOR_BLUE)Uninstalling sym (local)...$(COLOR_RESET)"
	@$(RM) $(INSTALL_BIN)/sym
	@$(RM) $(INSTALL_MAN)/$(MANPAGE_GZ)
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Uninstalled"

# Clean build artifacts
clean:
	@echo "$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	@$(RM) $(MANPAGE) $(MANPAGE_GZ)
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Cleaned"

# Test the script
test:
	@echo "$(COLOR_BLUE)Running tests...$(COLOR_RESET)"
	@bash $(SCRIPT) --version
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Version check passed"
	@bash $(SCRIPT) --help > /dev/null
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Help command passed"
	@bash -n $(SCRIPT)
	@echo "$(COLOR_GREEN)✓$(COLOR_RESET) Syntax check passed"
	@echo ""
	@echo "$(COLOR_GREEN)All tests passed!$(COLOR_RESET)"

# Check if pandoc is installed
check-pandoc:
	@command -v $(PANDOC) >/dev/null 2>&1 || { \
		echo "$(COLOR_YELLOW)Warning:$(COLOR_RESET) pandoc is not installed."; \
		echo ""; \
		echo "To build the man page, install pandoc:"; \
		echo "  macOS:   brew install pandoc"; \
		echo "  Ubuntu:  sudo apt install pandoc"; \
		echo "  Fedora:  sudo dnf install pandoc"; \
		echo ""; \
		exit 1; \
	}

# View the built man page
view: $(MANPAGE)
	@man ./$(MANPAGE)

# View the compressed man page
view-gz: $(MANPAGE_GZ)
	@man ./$(MANPAGE_GZ)

# Help target
help:
	@echo "$(COLOR_BLUE)sym Makefile - Available targets:$(COLOR_RESET)"
	@echo ""
	@echo "  $(COLOR_GREEN)make$(COLOR_RESET) or $(COLOR_GREEN)make build$(COLOR_RESET)"
	@echo "      Build the man page from markdown source"
	@echo ""
	@echo "  $(COLOR_GREEN)make install$(COLOR_RESET)"
	@echo "      Install sym and man page system-wide (requires sudo)"
	@echo "      Installs to: $(BINDIR)/sym"
	@echo "      Man page:    $(MANDIR)/sym.1.gz"
	@echo ""
	@echo "  $(COLOR_GREEN)make install-local$(COLOR_RESET)"
	@echo "      Install sym and man page to user directory (no sudo)"
	@echo "      Installs to: $(INSTALL_BIN)/sym"
	@echo "      Man page:    $(INSTALL_MAN)/sym.1.gz"
	@echo ""
	@echo "  $(COLOR_GREEN)make uninstall$(COLOR_RESET)"
	@echo "      Uninstall system-wide installation"
	@echo ""
	@echo "  $(COLOR_GREEN)make uninstall-local$(COLOR_RESET)"
	@echo "      Uninstall local installation"
	@echo ""
	@echo "  $(COLOR_GREEN)make clean$(COLOR_RESET)"
	@echo "      Remove built files (sym.1, sym.1.gz)"
	@echo ""
	@echo "  $(COLOR_GREEN)make test$(COLOR_RESET)"
	@echo "      Run basic tests on the script"
	@echo ""
	@echo "  $(COLOR_GREEN)make view$(COLOR_RESET)"
	@echo "      View the built man page"
	@echo ""
	@echo "  $(COLOR_GREEN)make help$(COLOR_RESET)"
	@echo "      Show this help message"
	@echo ""
	@echo "$(COLOR_BLUE)Requirements:$(COLOR_RESET)"
	@echo "  - pandoc (for building man page)"
	@echo "  - gzip (for compressing man page)"
	@echo ""
	@echo "$(COLOR_BLUE)Environment Variables:$(COLOR_RESET)"
	@echo "  PREFIX       Installation prefix (default: /usr/local)"
	@echo "  INSTALL_BIN  Local bin directory (default: ~/.local/bin)"
	@echo "  INSTALL_MAN  Local man directory (default: ~/.local/share/man/man1)"
