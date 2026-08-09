#!/usr/bin/env bash
# Render an image for nnn's preview pane.
#
# preview-tui kills the previewer the instant the selection changes. Being
# killed halfway through a kitty/sixel escape sequence leaves the terminal (and
# tmux, when passthrough is in play) waiting for a terminator and swallowing
# everything that follows, so the pane just goes blank and stays blank. Decode
# into memory first, where a kill costs nothing, then write the finished frame
# out in one go with the signals blocked.

size=$(stty size </dev/tty 2>/dev/null) || size="24 80"
rows=${size%% *}
cols=${size##* }

# The format is decided once per nnn session by term-caps; probing here would
# put a terminal round trip inside the very window we are trying to protect.
frame=$(
	chafa \
		--probe off \
		--format "${NNN_IMGFORMAT:-symbols}" \
		--passthrough auto \
		--animate off \
		--size "${cols}x$((rows - 1))" \
		-- "$1"
) || exit 0

trap '' HUP INT TERM
printf '%s' "$frame"
