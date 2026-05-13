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

# Bootstrap gum for interactive menus. Failure is expected in minimal environments.
bootstrap_gum || true

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
declare -a AGENT_KEYS=("gh" "copilot" "codex" "claude" "gemini" "pi")
declare -A AGENTS
AGENTS=(
    ["gh"]="GitHub CLI"
    ["copilot"]="GitHub Copilot CLI"
    ["codex"]="Codex"
    ["claude"]="Claude"
    ["gemini"]="Gemini"
    ["pi"]="Pi"
)

agent_is_selected() {
    local needle="$1"
    local agent

    for agent in "${SELECTED_AGENTS[@]:-}"; do
        if [[ "$agent" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

agent_is_detected() {
    local needle="$1"
    local agent

    for agent in "${DETECTED_AGENTS[@]:-}"; do
        if [[ "$agent" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

select_agent_once() {
    local agent="$1"

    if ! agent_is_selected "$agent"; then
        SELECTED_AGENTS+=("$agent")
    fi
}

agent_is_newly_selected() {
    local needle="$1"
    local agent

    for agent in "${NEWLY_SELECTED_AGENTS[@]:-}"; do
        if [[ "$agent" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

select_new_agent_once() {
    local agent="$1"

    select_agent_once "$agent"

    if ! agent_is_detected "$agent" && ! agent_is_newly_selected "$agent"; then
        NEWLY_SELECTED_AGENTS+=("$agent")
    fi
}

SELECTED_AGENTS=()
DETECTED_AGENTS=()
NEWLY_SELECTED_AGENTS=()

if [[ -f ".envrc" ]]; then
    grep -qE '^[[:space:]]*export[[:space:]]+GH_CONFIG_DIR=' .envrc && DETECTED_AGENTS+=("gh")
    grep -qE '^[[:space:]]*export[[:space:]]+COPILOT_HOME=' .envrc && DETECTED_AGENTS+=("copilot")
    grep -qE '^[[:space:]]*export[[:space:]]+CODEX_HOME=' .envrc && DETECTED_AGENTS+=("codex")
    grep -qE '^[[:space:]]*export[[:space:]]+CLAUDE_CONFIG_DIR=' .envrc && DETECTED_AGENTS+=("claude")
    grep -qE '^[[:space:]]*export[[:space:]]+GEMINI_CLI_HOME=' .envrc && DETECTED_AGENTS+=("gemini")
    grep -qE '^[[:space:]]*export[[:space:]]+PI_CODING_AGENT_DIR=' .envrc && DETECTED_AGENTS+=("pi")
fi

if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
    info "Already configured in .envrc:"
    for agent in "${DETECTED_AGENTS[@]}"; do
        echo "  • ${AGENTS[$agent]}"
        select_agent_once "$agent"
    done
    echo ""
fi

if [[ -n "$GUM" ]] && has_tty; then
    # Use gum for beautiful checkbox UI when a TTY is available
    info "Which additional AI agents would you like to configure?"
    echo ""

    # Build options for gum
    OPTIONS=()
    for key in "${AGENT_KEYS[@]}"; do
        if ! agent_is_detected "$key"; then
            OPTIONS+=("${AGENTS[$key]}")
        fi
    done

    if [[ ${#OPTIONS[@]} -eq 0 ]]; then
        info "All supported agents are already configured. Existing agents will be refreshed where applicable."
    else
        # Let user select with checkboxes
        SELECTED=$("$GUM" choose --no-limit --header "Select agents to add (already configured agents are preserved):" "${OPTIONS[@]}" || true)

        # Map selections back to keys
        while IFS= read -r line; do
            for key in "${AGENT_KEYS[@]}"; do
                if [[ "${AGENTS[$key]}" == "$line" ]]; then
                    select_new_agent_once "$key"
                    break
                fi
            done
        done <<< "$SELECTED"
    fi
else
    # Fallback to simple y/N prompts
    info "Which additional AI agents would you like to configure?"
    echo "  Existing agents are preserved. Select any new agents you want to add."
    echo ""
    
    for key in "${AGENT_KEYS[@]}"; do
        if agent_is_selected "$key"; then
            info "Keeping ${AGENTS[$key]}"
            continue
        fi

        read -p "$(echo -e ${YELLOW}  Add ${AGENTS[$key]}? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            select_new_agent_once "$key"
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

setup_claude_statusline() {
    local claude_dir=".agent-profile/claude"
    local local_settings_dir=".claude"
    local local_settings_file="${local_settings_dir}/settings.local.json"
    local legacy_profile_settings_file="${claude_dir}/settings.json"
    local statusline_script="${claude_dir}/statusline.sh"
    local statusline_command='bash "$CLAUDE_CONFIG_DIR/statusline.sh"'

    if [[ ! -f "$statusline_script" ]]; then
        cat > "$statusline_script" <<'CLAUDE_STATUSLINE'
#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"

json_value() {
    local key="$1"
    python3 -c '
import json
import sys

data = json.load(sys.stdin)
value = data
for part in sys.argv[1].split("."):
    if not isinstance(value, dict):
        value = ""
        break
    value = value.get(part, "")
if value is None:
    value = ""
print(value)
' "$key" <<< "$input"
}

model="$(json_value model.display_name)"
current_dir="$(json_value workspace.current_dir)"
context_pct="$(json_value context_window.used_percentage)"
dir_name="${current_dir##*/}"

branch=""
dirty=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git branch --show-current 2>/dev/null || true)"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        dirty="*"
    fi
fi

if [[ -z "$context_pct" ]]; then
    context_pct="0"
fi
context_pct="${context_pct%.*}"

cyan=$'\033[36m'
green=$'\033[32m'
reset=$'\033[0m'

line="${cyan}${dir_name}${reset}"
if [[ -n "$branch" ]]; then
    line+=" | ${branch}${dirty}"
fi
if [[ -n "$model" ]]; then
    line+=" | ${model}"
fi
line+=" | ${green}${context_pct}%${reset}"

echo -e "$line"
CLAUDE_STATUSLINE
        chmod +x "$statusline_script"
        success "Created Claude statusline script"
    else
        info "Claude statusline script already exists"
    fi

    mkdir -p "$local_settings_dir"

    if [[ ! -f "$local_settings_file" ]]; then
        {
            echo '{'
            echo '  "statusLine": {'
            echo '    "type": "command",'
            echo '    "command": "bash \"$CLAUDE_CONFIG_DIR/statusline.sh\"",'
            echo '    "padding": 0'
            echo '  }'
            echo '}'
        } > "$local_settings_file"
        success "Created Claude local settings with repo-local statusline"
    elif grep -q '"statusLine"' "$local_settings_file"; then
        info "Claude local settings already include statusLine"
    elif command -v python3 >/dev/null 2>&1; then
        STATUSLINE_COMMAND="$statusline_command" python3 - "$local_settings_file" <<'PY'
import json
import os
import sys

settings_path = sys.argv[1]
with open(settings_path, "r", encoding="utf-8") as f:
    data = json.load(f)

data["statusLine"] = {
    "type": "command",
    "command": os.environ["STATUSLINE_COMMAND"],
    "padding": 0,
}

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
        success "Updated Claude local settings with repo-local statusline"
    else
        warning "Claude local settings already exist without statusLine: ${local_settings_file}"
        warning "Install python3 so the installer can merge settings, or run /statusline inside local Claude."
    fi

    if [[ -f "$legacy_profile_settings_file" ]]; then
        warning "Found legacy Claude profile settings that Claude Code does not read for statusLine: ${legacy_profile_settings_file}"
    fi
}

if agent_is_selected "claude"; then
    setup_claude_statusline
fi

# Generate the installer-managed .envrc block for selected agents.
ENVRC_BEGIN_MARKER="# >>> ai-agent-profile-template >>>"
ENVRC_END_MARKER="# <<< ai-agent-profile-template <<<"

generate_envrc_block() {
    local agents=("$@")
    local agent

    {
        echo "$ENVRC_BEGIN_MARKER"
        echo '# Generated by install.sh. Re-run the installer to add more agents.'
        echo '# Profiles are stored under this repository only (never shared via $HOME).'
        echo '# Anchor to the .envrc location so paths stay repo-scoped even from subdirectories.'
        echo 'REPO_ROOT="$(cd "$(dirname "${DIRENV_FILE}")" && pwd)"'
        echo 'PROFILE_DIR="${REPO_ROOT}/.agent-profile"'

        for agent in "${agents[@]}"; do
            case $agent in
                gh)
                    echo ''
                    echo '# GitHub CLI account scope'
                    echo 'export GH_CONFIG_DIR="${PROFILE_DIR}/gh"'
                    echo 'export GH_TOKEN=""'
                    echo 'export GITHUB_TOKEN=""'
                    ;;
                copilot)
                    echo ''
                    echo '# GitHub Copilot CLI account, MCP, plugins, sessions, and settings scope'
                    echo 'export COPILOT_HOME="${PROFILE_DIR}/copilot"'
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
        echo "$ENVRC_END_MARKER"
    }
}

write_envrc() {
    local target="$1"
    local block_file merged_file
    local agents_to_write=("${SELECTED_AGENTS[@]}")
    local agent

    block_file="$(mktemp)"
    TMPFILES+=("$block_file")

    if [[ ! -f "$target" ]]; then
        generate_envrc_block "${agents_to_write[@]}" > "$block_file"
        cp "$block_file" "$target"
        return 0
    fi

    if grep -qF "$ENVRC_BEGIN_MARKER" "$target" && grep -qF "$ENVRC_END_MARKER" "$target"; then
        generate_envrc_block "${agents_to_write[@]}" > "$block_file"
        merged_file="$(mktemp)"
        TMPFILES+=("$merged_file")
        awk -v begin="$ENVRC_BEGIN_MARKER" -v end="$ENVRC_END_MARKER" -v block_file="$block_file" '
            BEGIN {
                while ((getline line < block_file) > 0) {
                    block = block line ORS
                }
                in_block = 0
            }
            $0 == begin {
                printf "%s", block
                in_block = 1
                next
            }
            $0 == end {
                in_block = 0
                next
            }
            !in_block {
                print
            }
        ' "$target" > "$merged_file"
        mv "$merged_file" "$target"
        return 0
    fi

    if grep -qF '# Generated by install.sh' "$target"; then
        generate_envrc_block "${agents_to_write[@]}" > "$block_file"
        cp "$block_file" "$target"
        return 0
    fi

    agents_to_write=()
    for agent in "${SELECTED_AGENTS[@]}"; do
        if ! agent_is_detected "$agent"; then
            agents_to_write+=("$agent")
        fi
    done

    if [[ ${#agents_to_write[@]} -eq 0 ]]; then
        return 1
    fi

    generate_envrc_block "${agents_to_write[@]}" > "$block_file"
    {
        echo ""
        cat "$block_file"
    } >> "$target"
}

ENVRC_CHANGED=false
DIRENV_ALLOWED=false

if [[ -f ".envrc" ]]; then
    if write_envrc ".envrc"; then
        ENVRC_CHANGED=true
        success "Updated .envrc for configured agents"
    else
        info ".envrc already contains the detected agent configuration"
    fi
else
    write_envrc ".envrc"
    ENVRC_CHANGED=true
    success "Generated .envrc for selected agents"
fi

if [[ "$ENVRC_CHANGED" == true ]]; then
    if command -v direnv >/dev/null 2>&1; then
        info "Allowing direnv for this repository..."
        if direnv allow; then
            DIRENV_ALLOWED=true
            success "direnv allowed for this repository"
        else
            warning "direnv allow failed. You may need to run it manually after install."
        fi
    else
        warning "direnv is not available, so .envrc could not be allowed automatically."
    fi
fi

# Merge .gitignore entries
info "Updating .gitignore..."

GITIGNORE_ENTRIES=(
    "# AI Agent profiles (local auth, never commit)"
    ".envrc"
    ".agent-profile/"
    ".claude/settings.local.json"
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

HAS_NEW_GH_SELECTED=false
for agent in "${NEWLY_SELECTED_AGENTS[@]}"; do
    if [[ "$agent" == "gh" ]]; then
        HAS_NEW_GH_SELECTED=true
        break
    fi
done

GH_AUTH_DONE=false
GH_AUTH_NEEDS_MANUAL=false
GH_AUTH_MANUAL_REASON=""

if [[ "$HAS_NEW_GH_SELECTED" == true ]]; then
    echo ""
    info "GitHub CLI setup"

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
NEXT_STEP=1

if [[ "$DIRENV_ALLOWED" == true ]]; then
    echo "${NEXT_STEP}. direnv has already been allowed for this repository."
else
    echo "${NEXT_STEP}. Allow direnv for this repository:"
    echo -e "   ${GREEN}direnv allow${NC}"
fi
echo ""
NEXT_STEP=$((NEXT_STEP + 1))

if [[ ${#SELECTED_AGENTS[@]} -gt 0 ]]; then
    echo "${NEXT_STEP}. Use your normal AI CLI commands as usual."
    echo "   Most tools will prompt you to authenticate on first run."
    echo ""
    NEXT_STEP=$((NEXT_STEP + 1))
fi

if [[ "$GH_AUTH_DONE" == true ]]; then
    echo -e "${BLUE}GitHub CLI:${NC}"
    echo "   Repo-local GitHub auth was completed during install."
    echo ""
fi

if [[ "$GH_AUTH_NEEDS_MANUAL" == true ]]; then
    echo -e "${BLUE}Additional GitHub CLI step:${NC}"
    echo "   ${GH_AUTH_MANUAL_REASON}"
    echo "   Run this once inside the repository:"
    echo "   GH_CONFIG_DIR=\"\$PWD/.agent-profile/gh\" gh auth login"
    echo ""
fi

echo "${NEXT_STEP}. Start using your AI agents in this repository!"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
