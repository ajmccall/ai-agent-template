#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory (where to install)
TARGET_DIR="${1:-$PWD}"

# Gum configuration
GUM_VERSION="0.17.0"
GUM=""
TMPFILES=()

# Cleanup function for temporary files
cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -rf "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AI Agent Profile Installer                            ║${NC}"
echo -e "${BLUE}║   Per-repo authentication for multiple AI agents        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print status messages
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect OS and architecture
detect_os() {
    case "$(uname -s 2>/dev/null || true)" in
        Darwin) echo "Darwin" ;;
        Linux) echo "Linux" ;;
        *) echo "unsupported" ;;
    esac
}

detect_arch() {
    case "$(uname -m 2>/dev/null || true)" in
        x86_64|amd64) echo "x86_64" ;;
        arm64|aarch64) echo "arm64" ;;
        i386|i686) echo "i386" ;;
        armv7l|armv7) echo "armv7" ;;
        armv6l|armv6) echo "armv6" ;;
        *) echo "unknown" ;;
    esac
}

# Bootstrap gum for interactive UI
bootstrap_gum() {
    # Check if gum is already installed
    if command -v gum >/dev/null 2>&1; then
        GUM="gum"
        info "Using installed gum"
        return 0
    fi

    # Check if we can download gum
    if ! command -v curl >/dev/null 2>&1; then
        warning "curl not found, skipping gum (falling back to basic prompts)"
        return 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        warning "tar not found, skipping gum (falling back to basic prompts)"
        return 1
    fi

    local os arch asset base gum_tmpdir gum_path
    os="$(detect_os)"
    arch="$(detect_arch)"
    
    if [[ "$os" == "unsupported" || "$arch" == "unknown" ]]; then
        warning "Unsupported OS/arch ($os/$arch), skipping gum"
        return 1
    fi

    info "Downloading gum for better UI experience..."
    
    asset="gum_${GUM_VERSION}_${os}_${arch}.tar.gz"
    base="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}"

    gum_tmpdir="$(mktemp -d)"
    TMPFILES+=("$gum_tmpdir")

    if ! curl -fsSL --proto '=https' --tlsv1.2 "${base}/${asset}" -o "$gum_tmpdir/$asset" 2>/dev/null; then
        warning "Failed to download gum (falling back to basic prompts)"
        return 1
    fi

    if ! tar -xzf "$gum_tmpdir/$asset" -C "$gum_tmpdir" >/dev/null 2>&1; then
        warning "Failed to extract gum (falling back to basic prompts)"
        return 1
    fi

    gum_path="$(find "$gum_tmpdir" -type f -name gum 2>/dev/null | head -n1 || true)"
    if [[ -z "$gum_path" ]]; then
        warning "gum binary not found after extraction"
        return 1
    fi

    chmod +x "$gum_path"
    GUM="$gum_path"
    success "Downloaded gum successfully"
    return 0
}

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR"
info "Installing to: $TARGET_DIR"
echo ""

# Bootstrap gum for interactive menus
bootstrap_gum

# Check if direnv is installed
info "Checking for direnv..."
if ! command -v direnv &> /dev/null; then
    warning "direnv is not installed"
    
    # Check if brew is available
    if command -v brew &> /dev/null; then
        read -p "$(echo -e ${YELLOW}Would you like to install direnv via Homebrew? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Installing direnv..."
            brew install direnv
            success "direnv installed"
            warning "Don't forget to add direnv hook to your shell rc file!"
            echo "  For zsh: echo 'eval \"\$(direnv hook zsh)\"' >> ~/.zshrc"
            echo "  For bash: echo 'eval \"\$(direnv hook bash)\"' >> ~/.bashrc"
        else
            warning "Skipping direnv installation. You'll need to install it manually."
        fi
    else
        warning "Homebrew not found. Please install direnv manually: https://direnv.net/"
    fi
else
    success "direnv is already installed"
fi
echo ""

# Interactive agent selection
declare -a AGENT_KEYS=("gh" "codex" "claude" "gemini")
declare -A AGENTS
AGENTS=(
    ["gh"]="GitHub Copilot (via gh CLI)"
    ["codex"]="Codex"
    ["claude"]="Claude"
    ["gemini"]="Gemini"
)

SELECTED_AGENTS=()

if [[ -n "$GUM" ]]; then
    # Use gum for beautiful checkbox UI
    info "Which AI agents would you like to configure?"
    echo ""
    
    # Build options for gum
    OPTIONS=()
    for key in "${AGENT_KEYS[@]}"; do
        OPTIONS+=("${AGENTS[$key]}")
    done
    
    # Let user select with checkboxes
    SELECTED=$("$GUM" choose --no-limit --header "Select AI agents (use space to select, enter to confirm):" "${OPTIONS[@]}" < /dev/tty || true)
    
    # Map selections back to keys
    while IFS= read -r line; do
        for key in "${AGENT_KEYS[@]}"; do
            if [[ "${AGENTS[$key]}" == "$line" ]]; then
                SELECTED_AGENTS+=("$key")
                break
            fi
        done
    done <<< "$SELECTED"
else
    # Fallback to simple y/N prompts
    info "Which AI agents would you like to configure?"
    echo "  Select the agents you want to use in this repository."
    echo ""
    
    for key in "${AGENT_KEYS[@]}"; do
        read -p "$(echo -e ${YELLOW}  Setup ${AGENTS[$key]}? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SELECTED_AGENTS+=("$key")
        fi
    done
fi

if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
    if [[ -n "$GUM" ]]; then
        if ! "$GUM" confirm "No agents selected. Continue anyway?" < /dev/tty; then
            warning "Installation cancelled."
            exit 0
        fi
    else
        read -p "$(echo -e ${YELLOW}No agents selected. Continue anyway? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            warning "Installation cancelled."
            exit 0
        fi
    fi
fi

echo ""
info "Setting up AI agent profiles..."

# Create .agent-profile directory structure
if [[ ! -d ".agent-profile" ]]; then
    mkdir -p .agent-profile
    success "Created .agent-profile directory"
else
    info ".agent-profile directory already exists"
fi

# Create subdirectories for selected agents
for agent in "${SELECTED_AGENTS[@]}"; do
    if [[ ! -d ".agent-profile/$agent" ]]; then
        mkdir -p ".agent-profile/$agent"
        success "Created .agent-profile/$agent directory"
    else
        info ".agent-profile/$agent already exists"
    fi
done

# Copy .envrc.example
if [[ -f "$SCRIPT_DIR/.envrc.example" ]]; then
    if [[ -f ".envrc" ]]; then
        warning ".envrc already exists"
        
        SHOULD_OVERWRITE=false
        if [[ -n "$GUM" ]]; then
            if "$GUM" confirm "Overwrite existing .envrc?" < /dev/tty; then
                SHOULD_OVERWRITE=true
            fi
        else
            read -p "$(echo -e ${YELLOW}  Overwrite existing .envrc? [y/N]:${NC} )" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                SHOULD_OVERWRITE=true
            fi
        fi
        
        if [[ "$SHOULD_OVERWRITE" == true ]]; then
            cp "$SCRIPT_DIR/.envrc.example" ".envrc"
            success "Copied .envrc.example to .envrc (overwrote existing)"
        else
            info "Keeping existing .envrc"
            info "You can copy from: $SCRIPT_DIR/.envrc.example"
        fi
    else
        cp "$SCRIPT_DIR/.envrc.example" ".envrc"
        success "Copied .envrc.example to .envrc"
    fi
else
    error "Could not find .envrc.example in $SCRIPT_DIR"
fi

# Merge .gitignore entries
info "Updating .gitignore..."

GITIGNORE_ENTRIES=(
    "# AI Agent profiles (local auth, never commit)"
    ".envrc"
    ".envrc.local"
    ".agent-profile/"
    ".ai-agents/"
    ".claude/"
    ".copilot/"
    ".codex/"
    ".gemini/"
)

if [[ -f ".gitignore" ]]; then
    # Check if entries already exist
    NEEDS_UPDATE=false
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qF "$entry" .gitignore; then
            NEEDS_UPDATE=true
            break
        fi
    done
    
    if [[ "$NEEDS_UPDATE" == true ]]; then
        # Append entries that don't exist
        {
            echo ""
            for entry in "${GITIGNORE_ENTRIES[@]}"; do
                if ! grep -qF "$entry" .gitignore; then
                    echo "$entry"
                fi
            done
        } >> .gitignore
        success "Updated .gitignore with AI agent entries"
    else
        info ".gitignore already contains AI agent entries"
    fi
else
    # Create new .gitignore
    {
        for entry in "${GITIGNORE_ENTRIES[@]}"; do
            echo "$entry"
        done
    } > .gitignore
    success "Created .gitignore with AI agent entries"
fi

# Copy Brewfile if it doesn't exist
if [[ -f "$SCRIPT_DIR/Brewfile" ]] && [[ ! -f "Brewfile" ]]; then
    SHOULD_COPY=false
    if [[ -n "$GUM" ]]; then
        if "$GUM" confirm "Copy Brewfile?" < /dev/tty; then
            SHOULD_COPY=true
        fi
    else
        read -p "$(echo -e ${YELLOW}Copy Brewfile? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SHOULD_COPY=true
        fi
    fi
    
    if [[ "$SHOULD_COPY" == true ]]; then
        cp "$SCRIPT_DIR/Brewfile" "Brewfile"
        success "Copied Brewfile"
    fi
fi

echo ""
success "Installation complete!"
echo ""

# Summary and next steps
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ ${#SELECTED_AGENTS[@]} -gt 0 ]]; then
    echo -e "${BLUE}Configured agents:${NC}"
    for agent in "${SELECTED_AGENTS[@]}"; do
        echo "  • ${AGENTS[$agent]}"
    done
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Allow direnv for this repository:"
echo -e "   ${GREEN}direnv allow${NC}"
echo ""

if [[ ${#SELECTED_AGENTS[@]} -gt 0 ]]; then
    echo "2. Authenticate each AI agent:"
    echo ""
    
    for agent in "${SELECTED_AGENTS[@]}"; do
        case $agent in
            gh)
                echo -e "   ${BLUE}GitHub Copilot:${NC}"
                echo "   GH_CONFIG_DIR=\"\$PWD/.agent-profile/gh\" gh auth login"
                echo ""
                ;;
            codex)
                echo -e "   ${BLUE}Codex:${NC}"
                echo "   codex  # Authenticate when prompted"
                echo ""
                ;;
            claude)
                echo -e "   ${BLUE}Claude:${NC}"
                echo "   claude  # Authenticate when prompted"
                echo ""
                ;;
            gemini)
                echo -e "   ${BLUE}Gemini:${NC}"
                echo "   gemini  # Authenticate when prompted"
                echo ""
                ;;
        esac
    done
fi

echo "3. Start using your AI agents in this repository!"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
