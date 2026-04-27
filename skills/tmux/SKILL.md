---
name: tmux
description: Run long-running commands in a tmux session and capture their output. Use when you need to start a build/test/server that takes minutes, run multiple commands in parallel, or interact with a process across tool calls.
---

# Tmux Skill

Drive `tmux` directly via shell commands — no MCP needed. Use this for any
long-running task whose output you'll want to inspect later, or for processes
that need to outlive a single Bash tool call.

## Session naming convention

All sessions you create must be prefixed with `claude-`. This keeps them
namespaced and lets you find idle ones to reuse.

## Find an idle session, or create one

Before starting a new session, check whether an existing `claude-*` session
is idle and reuse it. A session is "idle" if its current pane is at a shell
prompt with no running command.

```bash
# List existing claude- sessions
tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^claude-' || true

# Create a fresh detached session
tmux new-session -d -s claude-build

# Create a session only if missing (idempotent)
tmux has-session -t claude-build 2>/dev/null || tmux new-session -d -s claude-build
```

## Run a command and wait for it

Send the command followed by a unique completion marker, then poll
`capture-pane` until the marker appears.

```bash
SESSION=claude-build
MARKER="__DONE_$$_$RANDOM__"

tmux send-keys -t "$SESSION" "your-long-command; echo $MARKER" Enter

# Poll until the marker shows up
until tmux capture-pane -p -t "$SESSION" | grep -q "$MARKER"; do
  sleep 2
done

# Capture the full output (scrollback included)
tmux capture-pane -p -S - -t "$SESSION"
```

Use `Bash(run_in_background=true)` for the polling loop if you want to do
other work while waiting.

## Capture output

```bash
# Just what's currently visible
tmux capture-pane -p -t claude-build

# Full scrollback (everything since session start)
tmux capture-pane -p -S - -t claude-build

# Last 200 lines of scrollback
tmux capture-pane -p -S -200 -t claude-build
```

`-p` prints to stdout. Without it, output goes to a paste buffer.

## Run things in parallel

Use multiple sessions or multiple windows in one session.

```bash
# Multiple sessions (independent, clean)
tmux new-session -d -s claude-build  -- bash -c 'nix build .#foo'
tmux new-session -d -s claude-tests  -- bash -c 'pytest'

# Multiple windows in one session
tmux new-session -d -s claude-work
tmux new-window  -t claude-work -n build  -- bash -c 'nix build .#foo'
tmux new-window  -t claude-work -n tests  -- bash -c 'pytest'
tmux list-windows -t claude-work
```

Note: when a command passed via `--` exits, the window closes too. To keep
the pane around for inspection, wrap with `bash -c 'cmd; exec bash'` or use
the `send-keys` pattern above.

## Inspect

```bash
tmux list-sessions                    # all sessions
tmux list-windows  -t claude-build    # windows in a session
tmux list-panes    -t claude-build    # panes in current window
```

## Clean up

```bash
tmux kill-session -t claude-build     # one session
tmux kill-server                      # everything (nuclear)
```

## When NOT to use tmux

- One-shot commands that complete in seconds → just use `Bash` directly.
- Commands you want to background but don't need to interact with later →
  `Bash(run_in_background=true)` is simpler.
- Anything that needs structured stdout/stderr separation — tmux merges them.
