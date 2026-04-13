# Per-Repo AI Agent Profiles

Keep GitHub, Codex, Claude, and Gemini logins scoped to a single repository.

This template uses `direnv` to make AI CLI profiles repo-local, so each repository can keep its own isolated login state under `.agent-profile/` instead of reusing global auth from your home directory.

**Good for:** consultants, agencies, multi-org teams, and anyone separating personal/work AI accounts.

## Supported tools

- ✅ GitHub / Copilot
- ✅ Codex
- ✅ Claude
- ✅ Gemini

## Sections

[Why this exists](#why-this-exists) · [Quick start](#quick-start) · [Common use cases](#common-use-cases) · [How it works](docs/how-it-works.md)

## Why this exists

Most AI CLIs store auth and config globally in `~/.config`, `~/.claude`, or other home-directory locations.

That becomes painful when you:
- work across multiple clients
- switch between personal and work accounts
- need different GitHub identities in different repos
- want to avoid accidental cross-client auth reuse

This template makes auth local and explicit:
- one repo = one local profile directory
- fast switching with `direnv`
- safer account separation
- easy to inspect, back up, or remove

### Before
- one global login shared across repos
- easy to authenticate the wrong client/account
- CLI state spread across your home directory

### After
- isolated auth per repository
- account switching tied to `cd` + `direnv`
- repo-local config under `.agent-profile/`

## Common use cases

### Consultant or freelancer
Use different GitHub / Claude / Codex accounts for different client repositories.

### Agency or studio
Keep customer AI credentials isolated per project instead of sharing one global machine-wide login.

### Personal + work separation
Use one identity for company repos and another for side projects.

### Testing and demos
Create temporary or sandboxed agent profiles without disturbing your normal setup.

## See it in action

A good demo to add here later:
- a GIF showing `cd client-a` → `gh auth status`
- then `cd ../client-b` → different `gh auth status`
- optionally also show `echo $GH_CONFIG_DIR`

That visual would make the value obvious in a few seconds.

## Quick start

### Automated installation

Run the interactive installer from your target repository:

```shell
cd /path/to/your/project
bash /path/to/ai-agent-profile-template/install.sh
```

Or provide the target directory as an argument:

```shell
/path/to/ai-agent-profile-template/install.sh /path/to/your/project
```

### What the installer does

- checks for `direnv`
- downloads `gum` for interactive selection when possible
- lets you choose which agents to configure
- creates `.agent-profile/` directories for selected agents
- generates `.envrc`
- updates `.gitignore`
- optionally copies `Brewfile`
- if GitHub CLI is installed and you selected GitHub/Copilot, can optionally run repo-local `gh auth login`
- prints any remaining post-install steps

### After install

```shell
direnv allow
```

Then use your normal AI CLIs as usual.

Most tools will prompt you to authenticate on first run.

GitHub / Copilot is the main exception: if needed, the installer will tell you to run this one-time setup step:

```shell
GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login
```

## Manual setup

<details>
<summary>Show manual setup steps</summary>

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
mkdir -p .agent-profile/{gh,codex,claude,gemini}
direnv allow
```

Then use your normal AI CLIs as usual.

Most tools will prompt you to authenticate on first run.

If you want GitHub / Copilot in this repo-local profile, run:

```shell
GH_CONFIG_DIR="$PWD/.agent-profile/gh" gh auth login
```

</details>

## How it works

Short version:
- `direnv` loads `.envrc` when you enter the repo
- `.envrc` points each CLI at `.agent-profile/...`
- each repository gets its own local auth/config state

For the implementation details, see [docs/how-it-works.md](docs/how-it-works.md).

## How to uninstall

Remove the repo-local files and stop loading them with `direnv`:

```shell
rm -rf .agent-profile .envrc
```

Optionally remove the ignore entries from `.gitignore` if you no longer want them:

```gitignore
.envrc
.agent-profile/
```

## FAQ

### Is `.agent-profile/` committed?
No. The installer adds `.envrc` and `.agent-profile/` to `.gitignore`.

### Do I need every tool?
No. The installer generates directories and env vars only for the agents you select.

### Can I keep using global auth elsewhere?
Yes. This setup only affects repositories where you enable it.

### Does this work from subdirectories?
Yes. Paths are anchored from the `.envrc` location so the profile stays repo-scoped.

## Suggested future improvements

- add a GIF showing switching between two GitHub accounts across repos
- add screenshots of the installer flow
- add a troubleshooting doc for shell / `direnv` issues
- add example team workflows for agencies and consultancies

## License

See [LICENSE](LICENSE).
