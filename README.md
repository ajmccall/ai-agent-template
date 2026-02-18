### Per-Repo Agent Profiles (Copilot, Codex, Claude, Gemini)

This template is designed for companies (and independent consultancies) managing multiple clients and multiple AI agents. 

This repo supports strict `direnv`-based profile switching so each repository uses its own local CLI auth context.

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