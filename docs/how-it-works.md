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
    ├── codex/
    ├── claude/
    └── gemini/
```

When you `cd` into the repo, `direnv` loads `.envrc`, and the selected tools pick up config from `.agent-profile/...`.

## Environment variables used

Depending on which agents you select, the installer writes some of these variables to `.envrc`:

```shell
export GH_CONFIG_DIR="${PROFILE_DIR}/gh"
export GH_TOKEN=""
export GITHUB_TOKEN=""
export CODEX_HOME="${PROFILE_DIR}/codex"
export CLAUDE_CONFIG_DIR="${PROFILE_DIR}/claude"
export GEMINI_CLI_HOME="${PROFILE_DIR}/gemini"
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
4. creates `.agent-profile/` and selected subdirectories
5. generates `.envrc` for the chosen tools
6. updates `.gitignore` with local-only entries
7. optionally copies `Brewfile`

## Why `.gitignore` is updated

These files should stay local:

```gitignore
.envrc
.agent-profile/
```

That prevents repo-local auth state from being committed.

## Tool-specific notes

### GitHub CLI / Copilot
GitHub auth is redirected with:

```shell
export GH_CONFIG_DIR="${PROFILE_DIR}/gh"
```

Authenticate with:

```shell
GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login
```

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

### Gemini
Gemini is redirected with:

```shell
export GEMINI_CLI_HOME="${PROFILE_DIR}/gemini"
```

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
