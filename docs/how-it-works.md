# How It Works

This repo uses `direnv` to make AI CLI auth and config local to a repository.

## The core idea

Most CLI tools store auth in global locations under your home directory.
That means one login often gets reused everywhere on your machine.

This template redirects each tool to a repo-local directory instead:

```text
your-repo/
├── .envrc
└── .agent-profile/
    ├── gh/
    ├── copilot/
    ├── codex/
    ├── claude/
    ├── gemini/
    └── pi/
```

When you `cd` into the repo, `direnv` loads `.envrc`, and the selected tools pick up config from `.agent-profile/...`.

## Environment variables used

Depending on which agents you select, the installer writes some of these variables to `.envrc`:

```shell
export GH_CONFIG_DIR="${PROFILE_DIR}/gh"
export GH_TOKEN=""
export GITHUB_TOKEN=""
export COPILOT_HOME="${PROFILE_DIR}/copilot"
export CODEX_HOME="${PROFILE_DIR}/codex"
export CLAUDE_CONFIG_DIR="${PROFILE_DIR}/claude"
export GEMINI_CLI_HOME="${PROFILE_DIR}/gemini"
export PI_CODING_AGENT_DIR="${PROFILE_DIR}/pi"
```

## Why paths are anchored from `.envrc`

The generated `.envrc` uses:

```shell
REPO_ROOT="$(cd "$(dirname "${DIRENV_FILE}")" && pwd)"
PROFILE_DIR="${REPO_ROOT}/.agent-profile"
```

That matters because it keeps the profile repo-scoped even when commands are run from subdirectories.

Without anchoring to `DIRENV_FILE`, relative paths could depend on the current working directory and become inconsistent.

## Installer behavior

`install.sh` does the following:

1. validates the target directory
2. checks for `direnv`
3. uses `gum` for interactive selection when available and when a TTY exists
4. detects agents already configured in `.envrc`
5. creates `.agent-profile/` and selected subdirectories
6. creates a repo-local Claude statusline script and local project settings for new Claude profiles
7. generates or updates the installer-managed `.envrc` section
8. runs `direnv allow` after generating or updating `.envrc`
9. updates `.gitignore` with local-only entries
10. optionally copies `Brewfile`

## Why `.gitignore` is updated

These files should stay local:

```gitignore
.envrc
.agent-profile/
.claude/settings.local.json
```

That prevents repo-local auth state from being committed.

## Tool-specific notes

### GitHub CLI
GitHub auth is redirected with:

```shell
export GH_CONFIG_DIR="${PROFILE_DIR}/gh"
```

Authenticate with:

```shell
GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login
```

### Copilot CLI
Copilot CLI is redirected with:

```shell
export COPILOT_HOME="${PROFILE_DIR}/copilot"
```

This scopes Copilot's auth state, MCP server configuration, plugins, sessions, and settings away from the default `~/.copilot` directory.

### Codex
Codex is redirected with:

```shell
export CODEX_HOME="${PROFILE_DIR}/codex"
```

### Claude
Claude is redirected with:

```shell
export CLAUDE_CONFIG_DIR="${PROFILE_DIR}/claude"
```

When Claude is selected, the installer also creates `.agent-profile/claude/statusline.sh` and wires it through `.claude/settings.local.json`. Claude Code reads `statusLine` from its normal settings scopes, so the script lives in the repo-local profile while the setting itself is placed in Claude's project-local settings file.

### Gemini
Gemini is redirected with:

```shell
export GEMINI_CLI_HOME="${PROFILE_DIR}/gemini"
```

### Pi
Pi is redirected with:

```shell
export PI_CODING_AGENT_DIR="${PROFILE_DIR}/pi"
```

This scopes Pi's repo-local `auth.json`, `settings.json`, sessions, and other agent state away from the default `~/.pi/agent` directory.

## Operational model

A typical workflow looks like this:

1. enter a repository
2. `direnv` loads that repo's `.envrc`
3. CLI config paths point at that repo's `.agent-profile/`
4. the tool uses the repo-local login state
5. leaving the repo removes those environment variables

## When this is most useful

- multi-client consulting
- agencies supporting several orgs
- personal/work separation
- demos, sandboxes, and temporary accounts

## Caveats

- this relies on `direnv` being installed and enabled in your shell
- each CLI must support config redirection through environment variables
- existing global auth is not migrated automatically
- some tools may still read additional global state depending on their implementation

## Related files

- `README.md` — overview and quick start
- `install.sh` — interactive installer
- `.envrc.example` — example repo-local environment file
- `Brewfile` — local tooling dependencies
