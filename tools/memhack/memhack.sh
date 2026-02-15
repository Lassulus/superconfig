#!/usr/bin/env bash
pid=$(ps aux | fzf --header="Select a process to hack:" | awk '{print $2}')
if [ -z "$pid" ]; then
  echo "No process selected."
  exit 1
fi
exec sudo "$(command -v memhack-repl)" "$pid"
