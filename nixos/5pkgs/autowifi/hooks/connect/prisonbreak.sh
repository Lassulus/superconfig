#!/bin/sh
nix-shell $HOME/sync/prison-break --run 'python $HOME/sync/prison-break/prisonbreak/cli.py --force-run'
