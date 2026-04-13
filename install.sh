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

has_tty() {
    [[ -t 0 && -t 1 ]]
}

confirm_default_no() {
    local prompt="$1"

    if [[ -n "$GUM" ]] && has_tty; then
        "$GUM" confirm "$prompt"
    else
        read -p "$(echo -e ${YELLOW}${prompt} [y/N]:${NC} )" -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

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
declare -a AGENT_KEYS=("gh" "codex" "claude" "gemini" "pi")
declare -A AGENTS
AGENTS=(
    ["gh"]="GitHub Copilot (via gh CLI)"
    ["codex"]="Codex"
    ["claude"]="Claude"
    ["gemini"]="Gemini"
    ["pi"]="Pi"
)

SELECTED_AGENTS=()

if [[ -n "$GUM" ]] && has_tty; then
    # Use gum for beautiful checkbox UI when a TTY is available
    info "Which AI agents would you like to configure?"
    echo ""

    # Build options for gum
    OPTIONS=()
    for key in "${AGENT_KEYS[@]}"; do
        OPTIONS+=("${AGENTS[$key]}")
    done

    # Let user select with checkboxes
    SELECTED=$("$GUM" choose --no-limit --header "Select AI agents (use space to select, enter to confirm):" "${OPTIONS[@]}" || true)

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
    if [[ -n "$GUM" ]] && has_tty; then
        if ! "$GUM" confirm "No agents selected. Continue anyway?"; then
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

# Generate .envrc with only the selected agents' env vars
generate_envrc() {
    local target="$1"
    {
        echo '# Generated by install.sh — edit as needed.'
        echo '# Profiles are stored under this repository only (never shared via $HOME).'
        echo '# Anchor to the .envrc location so paths stay repo-scoped even from subdirectories.'
        echo 'REPO_ROOT="$(cd "$(dirname "${DIRENV_FILE}")" && pwd)"'
        echo 'PROFILE_DIR="${REPO_ROOT}/.agent-profile"'

        for agent in "${SELECTED_AGENTS[@]}"; do
            case $agent in
                gh)
                    echo ''
                    echo '# GitHub CLI / Copilot CLI account scope'
                    echo 'export GH_CONFIG_DIR="${PROFILE_DIR}/gh"'
                    echo 'export GH_TOKEN=""'
                    echo 'export GITHUB_TOKEN=""'
                    ;;
                codex)
                    echo ''
                    echo '# Codex account scope'
                    echo 'export CODEX_HOME="${PROFILE_DIR}/codex"'
                    ;;
                claude)
                    echo ''
                    echo '# Claude account scope'
                    echo 'export CLAUDE_CONFIG_DIR="${PROFILE_DIR}/claude"'
                    ;;
                gemini)
                    echo ''
                    echo '# Gemini CLI account scope'
                    echo 'export GEMINI_CLI_HOME="${PROFILE_DIR}/gemini"'
                    ;;
                pi)
                    echo ''
                    echo '# Pi coding agent account + config scope'
                    echo 'export PI_CODING_AGENT_DIR="${PROFILE_DIR}/pi"'
                    ;;
            esac
        done
    } > "$target"
}

if [[ -f ".envrc" ]]; then
    warning ".envrc already exists"

    SHOULD_OVERWRITE=false
    if [[ -n "$GUM" ]] && has_tty; then
        if "$GUM" confirm "Overwrite existing .envrc?"; then
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
        generate_envrc ".envrc"
        success "Generated .envrc for selected agents (overwrote existing)"
    else
        info "Keeping existing .envrc"
    fi
else
    generate_envrc ".envrc"
    success "Generated .envrc for selected agents"
fi

# Merge .gitignore entries
info "Updating .gitignore..."

GITIGNORE_ENTRIES=(
    "# AI Agent profiles (local auth, never commit)"
    ".envrc"
    ".agent-profile/"
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
    if [[ -n "$GUM" ]] && has_tty; then
        if "$GUM" confirm "Copy Brewfile?"; then
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

HAS_GH_SELECTED=false
for agent in "${SELECTED_AGENTS[@]}"; do
    if [[ "$agent" == "gh" ]]; then
        HAS_GH_SELECTED=true
        break
    fi
done

GH_AUTH_DONE=false
GH_AUTH_NEEDS_MANUAL=false
GH_AUTH_MANUAL_REASON=""

if [[ "$HAS_GH_SELECTED" == true ]]; then
    echo ""
    info "GitHub / Copilot setup"

    if command -v gh >/dev/null 2>&1; then
        if has_tty; then
            if confirm_default_no "Run repo-local GitHub auth now?"; then
                if GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login; then
                    GH_AUTH_DONE=true
                    success "GitHub auth completed for this repository profile"
                else
                    GH_AUTH_NEEDS_MANUAL=true
                    GH_AUTH_MANUAL_REASON="GitHub auth did not complete during install."
                fi
            else
                GH_AUTH_NEEDS_MANUAL=true
                GH_AUTH_MANUAL_REASON="GitHub auth was skipped during install."
            fi
        else
            GH_AUTH_NEEDS_MANUAL=true
            GH_AUTH_MANUAL_REASON="Installer was not running interactively."
        fi
    else
        GH_AUTH_NEEDS_MANUAL=true
        GH_AUTH_MANUAL_REASON="GitHub CLI ('gh') was not found."
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
    echo "2. Use your normal AI CLI commands as usual."
    echo "   Most tools will prompt you to authenticate on first run."
    echo ""
fi

if [[ "$GH_AUTH_DONE" == true ]]; then
    echo -e "${BLUE}GitHub / Copilot:${NC}"
    echo "   Repo-local GitHub auth was completed during install."
    echo ""
fi

if [[ "$GH_AUTH_NEEDS_MANUAL" == true ]]; then
    echo -e "${BLUE}Additional GitHub / Copilot step:${NC}"
    echo "   ${GH_AUTH_MANUAL_REASON}"
    echo "   Run this once inside the repository:"
    echo "   GH_CONFIG_DIR=\"\$PWD/.agent-profile/gh\" gh auth login"
    echo ""
fi

echo "3. Start using your AI agents in this repository!"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
