#!/usr/bin/env bash
# pinentry-auto: use pinentry-tty when a TTY is available, fall back to pinentry-rofi
if [ -t 0 ]; then
  exec pinentry-tty "$@"
else
  exec pinentry-rofi "$@"
fi
