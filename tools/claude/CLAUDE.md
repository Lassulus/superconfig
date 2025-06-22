# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Instructions

- Use `--log-format bar-with-logs` with Nix for improved build log output.
- Add new untracked files in Nix flakes with `git add`.
- Format code with `nix fmt` if available.
- Write shell scripts that pass ShellCheck.
- Write Python code for 3.12 that conforms to `ruff format` and passes `ruff check`.
- Always test/lint/format your code before committing.
- Add debug output or unit tests when troubleshooting.
- Avoid mocking in tests.
- Use the `gh` tool to interact with GitHub.
- Use `nix-locate` to find packages by file path.
- Use `nix run` to execute applications that are not installed.
- Do not include "claude" in commit messages.
- Use `nix eval` instead of `nix flake show` to look up attributes in a flake.
- Use tmux-mcp for long running tasks, use a session with a claude- prefix, create a session if you can't find any one that is idle
- Use git-mcp for advanced git operations like interactive staging, stash management, and bisecting
- Take extra care that we don't commit lines with trailing whitespaces