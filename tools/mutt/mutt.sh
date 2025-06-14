#!/usr/bin/env bash
# Export notmuch config and run neomutt with custom config
export NOTMUCH_CONFIG="$NOTMUCH_CONFIG_FILE"
exec neomutt -F "$MUTTRC" "$@"