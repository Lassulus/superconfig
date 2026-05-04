#!/usr/bin/env bash
set -euo pipefail

owner=Mic92
repo=tincr
branch=main
attr=tincr

pkg="$(dirname "$(realpath "$0")")/package.nix"

cd "$(dirname "$(realpath "$0")")"
while [ ! -e flake.nix ] && [ "$PWD" != / ]; do cd ..; done
system=$(nix eval --raw --impure --expr 'builtins.currentSystem')

new_rev=$(curl -fsSL "https://api.github.com/repos/$owner/$repo/commits/$branch" | jq -r .sha)
old_rev=$(grep -oP '^\s*rev = "\K[^"]+' "$pkg")
if [ "$old_rev" = "$new_rev" ]; then
  echo "$attr: already up to date ($new_rev)"
  exit 0
fi

new_date=$(curl -fsSL "https://api.github.com/repos/$owner/$repo/commits/$new_rev" | jq -r .commit.author.date | cut -d T -f1)
new_version="0-unstable-$new_date"

# Bump rev + version, leave hashes for nix to complain about.
sed -i \
  -e "s|^\(\s*\)rev = \".*\"|\1rev = \"$new_rev\"|" \
  -e "s|^\(\s*\)version = \".*\"|\1version = \"$new_version\"|" \
  "$pkg"

# Each FOD reports its own hash on first miss; build twice (src, then vendor).
extract_got() {
  awk '/got:/{print $2; exit}'
}
update_hash() {
  local field=$1 new=$2
  sed -i "s|^\(\s*\)$field = \"[^\"]*\"|\1$field = \"$new\"|" "$pkg"
}

build_attr=".#packages.$system.$attr"

if got=$(nix build --no-link "$build_attr" 2>&1 | tee /dev/stderr | extract_got) \
    && [ -n "$got" ]; then
  update_hash hash "$got"
  echo "$attr: src hash → $got"
fi

if got=$(nix build --no-link "$build_attr" 2>&1 | tee /dev/stderr | extract_got) \
    && [ -n "$got" ]; then
  update_hash cargoHash "$got"
  echo "$attr: cargoHash → $got"
fi

echo "$attr: updated to $new_rev ($new_version)"
nix build --no-link "$build_attr"
