#!/usr/bin/env bash
# Print the best graphics protocol this terminal speaks: kitty, sixels, iterm
# or symbols.
#
# The terminal is asked directly instead of guessing from the environment,
# because over ssh nothing on the remote host knows what is in front of the
# user. Run this once, before a full-screen program takes over the tty: chafa
# can probe on its own, but doing it per image races with nnn killing the
# previewer mid-sequence.

emit() {
	printf '%s\n' "$1"
	exit 0
}

case "${NNN_IMGFORMAT:-}" in
kitty | sixels | iterm | symbols) emit "$NNN_IMGFORMAT" ;;
esac

# Terminals that answer no query but identify themselves in the environment.
[ -n "${WEZTERM_PANE:-}" ] && emit iterm
[ "${TERM_PROGRAM:-}" = "iTerm.app" ] && emit iterm

query() {
	local saved
	local reply=""
	# a controlling terminal we can actually open, not just a device node;
	# bash reports a failing redirect before it applies 2>, hence the group
	{ : <>/dev/tty; } 2>/dev/null || return 1
	saved=$(stty -g </dev/tty) || return 1
	stty raw -echo </dev/tty || return 1
	# Kitty graphics support, then primary device attributes (which reports
	# sixel as attribute 4). Inside tmux both are smuggled out to the real
	# terminal: tmux would answer DA1 itself, on its own behalf, and that says
	# nothing about what can actually be drawn. Getting no answer at all is
	# informative too - it means passthrough is disabled.
	if [ -n "${TMUX:-}" ]; then
		printf '\033Ptmux;\033\033_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\033\033\134\033\134' >/dev/tty
		printf '\033Ptmux;\033\033[c\033\134' >/dev/tty
	else
		printf '\033_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\033\134\033[c' >/dev/tty
	fi
	# terminals answer in order, so the device attributes reply comes last and
	# its trailing "c" ends the exchange; the timeout only bites when nothing
	# is listening
	IFS= read -r -s -t 1 -d'c' reply </dev/tty || true
	stty "$saved" </dev/tty 2>/dev/null || true
	printf '%sc' "$reply"
}

capabilities=$(query || true)

# No answer to the graphics query inside tmux also means passthrough is off,
# in which case kitty images would arrive as blank placeholder cells.
case $capabilities in
*'_Gi=31;OK'*) emit kitty ;;
esac

case $capabilities in
*';4;'* | *';4c'* | *'?4;'* | *'?4c'*)
	# tmux advertises attribute 4 whenever it was built with sixel support,
	# regardless of what the attached client can actually draw
	if [ -z "${TMUX:-}" ]; then
		emit sixels
	fi
	case $(tmux display -p '#{client_termfeatures}' 2>/dev/null || true) in
	*sixel*) emit sixels ;;
	esac
	;;
esac

emit symbols
