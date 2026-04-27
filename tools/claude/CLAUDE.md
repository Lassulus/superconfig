# CLAUDE.md

Global guidance for Claude Code across all projects.

## Instructions

- Format code with the project's formatter before committing (e.g. `nix fmt`, `ruff format`, `prettier`).
- Write shell scripts that pass ShellCheck.
- Write Python code for 3.12 that conforms to `ruff format` and passes `ruff check`.
- Always test/lint/format your code before committing.
- Add debug output or unit tests when troubleshooting.
- Avoid mocking in tests.
- Use the `gh` tool to interact with GitHub.
- Do not include "claude" in commit messages.
- Take extra care not to commit lines with trailing whitespace.
- Use the `tmux` skill for long-running tasks. Use a session with a `claude-` prefix — create one if no idle session exists.
- Use git-mcp for advanced git operations (interactive staging, stash management, bisecting).

## Nix

When working in a Nix flake:

- Use `--log-format bar-with-logs` with `nix build` for improved build log output.
- Add new untracked files with `git add` — flake eval only sees tracked files.
- Use `nix-locate` to find packages by file path.
- Use `nix run nixpkgs#foo` to execute tools that aren't installed.
- Use `nix eval` instead of `nix flake show` to look up attributes in a flake.
  For listing: `nix eval .#packages.<system> --apply builtins.attrNames --json | jq`.
