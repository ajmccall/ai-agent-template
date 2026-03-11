### Per-Repo Agent Profiles (Copilot, Codex, Claude, Gemini)

This template is designed for companies (and independent consultancies) managing multiple clients and multiple AI agents. 

This repo supports strict `direnv`-based profile switching so each repository uses its own local CLI auth context.

## Quick Start

### Automated Installation (Recommended)

Run the interactive installer from your target repository:

```shell
cd /path/to/your/project
bash /path/to/ai-agent-profile-template/install.sh
```

Or provide the target directory as an argument:

```shell
/path/to/ai-agent-profile-template/install.sh /path/to/your/project
```

**The installer will:**
- ✅ Check and optionally install `direnv` via Homebrew
- ✅ Download `gum` for a beautiful interactive UI (or fall back to simple prompts)
- ✅ Present checkboxes to select which AI agents you want (GitHub Copilot, Codex, Claude, Gemini)
- ✅ Create `.agent-profile/` directory structure for selected agents
- ✅ Generate a `.envrc` containing only the env vars for your selected agents (with confirmation if it exists)
- ✅ Add `.envrc` and `.agent-profile/` to your `.gitignore` (without duplicates)
- ✅ Optionally copy the `Brewfile`
- ✅ Provide next steps for authenticating each agent

After installation, follow the on-screen instructions to:
1. Run `direnv allow` in your repository
2. Authenticate each AI agent you selected

---

### Manual Installation

If you prefer to set things up manually:

Install local tooling:

```shell
brew bundle
```

Enable `direnv` in your shell (one-time setup):

```shell
# zsh
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```

Open a new shell after adding the hook.

Configure repo-local environment:

```shell
cp .envrc.example .envrc
# Create a profile directory for any agent you want to use (gh, codex, claude, gemini, etc):
mkdir -p .agent-profile/{gh,codex,claude,gemini}
direnv allow
```

Now run your favorite agent CLI (e.g. `copilot`, `claude`, `codex`, `gemini`) to authenticate and set up your profile.

```shell
# Github Copilot (uses GH_CONFIG_DIR from .envrc)
copilot

# Codex (uses CODEX_HOME from .envrc)
codex

# Claude (uses CLAUDE_CONFIG_DIR from .envrc)
claude

# Gemini (uses GEMINI_CLI_HOME from .envrc)
gemini
```

#### Copilot (GitHub) profile setup

To use Copilot CLI with a repo-local profile, run the following command once:

```shell
GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login
```