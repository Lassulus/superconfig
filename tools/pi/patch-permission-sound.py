#!/usr/bin/env python3
"""Patch pi-hooks permission extension to play peon sounds via pw-play on Linux."""
import re
import sys

ts_file = sys.argv[1]
pw_play = sys.argv[2]

src = open(ts_file).read()

replacement = """function playPermissionSound(): void {
  const isMac = process.platform === "darwin";
  if (isMac) {
    exec('afplay /System/Library/Sounds/Funk.aiff 2>/dev/null', (err) => {
      if (err) process.stdout.write("\\x07");
    });
  } else {
    const n = Math.floor(Math.random() * 4) + 1;
    exec(`""" + pw_play + """ "$HOME/src/sounds/games/Warcraft III/Units/Orc/Peon/PeonWhat${n}.wav"`, () => {});
  }
}"""

result = re.sub(
    r'function playPermissionSound\(\): void \{.*?\n\}',
    replacement,
    src,
    flags=re.DOTALL,
)

if result == src:
    print("ERROR: playPermissionSound function not found in", ts_file, file=sys.stderr)
    sys.exit(1)

open(ts_file, 'w').write(result)
